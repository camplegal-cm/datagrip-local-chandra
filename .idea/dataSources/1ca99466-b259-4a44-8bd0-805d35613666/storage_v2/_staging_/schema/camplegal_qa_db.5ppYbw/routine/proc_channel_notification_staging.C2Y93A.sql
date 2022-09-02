create
    definer = root@`%` procedure proc_channel_notification_staging()
BEGIN
    DECLARE finished INTEGER DEFAULT 0;
    -- will be used to find end of loop in cursor
    -- variables to hold current-cursor fetch
    DECLARE Vcursor_break varchar(100) default null;
    DECLARE Vcursor_break_last_val varchar(100) default '0';
    DECLARE Vlaw_firm_id bigint default 0;
    DECLARE Vicase bigint default 0;
    DECLARE Vperson_id bigint default 0;
    DECLARE Vlanguage_preference varchar(4) default 'en';
    DECLARE Vdocument varchar(100) default null;
    DECLARE Vdescription text;
    DECLARE Vnotification_days bigint DEFAULT 0;
    DECLARE VemailAddress varchar(100) DEFAULT null;
    DECLARE vphone varchar(100) DEFAULT null;
    DECLARE vdocument_uuid varchar(500) DEFAULT null;
    DECLARE vcase_uuid varchar(100) DEFAULT null;

    DECLARE VDOCUMENT_STRING TEXT DEFAULT null;
    --  -- variables to hold previous-cursor fetch
    DECLARE Vllaw_firm_id bigint default 0;
    DECLARE Vlicase bigint default 0;
    DECLARE Vlperson_id bigint default 0;
    DECLARE Vllanguage_preference varchar(4) default 'en';
    DECLARE Vldocument varchar(100) default null;
    DECLARE V1description text;
    DECLARE Vlnotification_days bigint DEFAULT 0;
    DECLARE VlemailAddress varchar(100) DEFAULT null;
    DEClARE cur_channel_notification -- to improve efficiency and easy-maintenance build the catch-all sql to avoid nested cursors
        CURSOR FOR
        select distinct concat(cast(B.law_firm_id as char), '_', cast(icase as char), '_',
                               cast(A.person as char))             as cursor_break
                      , B.law_firm_id
                      , icase
                      , A.person
                      , coalesce(c.language, 'en')                    language_preference
                      , coalesce(t.language_text, A.document_type) as document          -- always use document_type,
                      -- , cp.value                                   AS notification_days -- once the notification days are added use the below line instead
                      , coalesce(cp.value, coalesce(B.value, 0))   as notification_days -- 12/22/2019 - replaced cp.value with this line.
                      , email
                      , coalesce(A.description, '')                as description
                      ,coalesce(c.phone,c.alt_phone) as phone
                      ,A.uuid as document_uuid
                      ,d.uuid as case_uuid

                      -- ,coalesce(cp.value,coalesce(B.value,0))
        from document A
                 inner join law_firm_preference B on A.law_firm = B.law_firm_id
                 left join case_preference cp on A.icase = cp.case_id
                 inner join person c on A.person = c.id
                 inner join icase d on A.icase = d.id
            -- prempting to only elligible cases to insert by using the left join and subquery
                 left join (
            -- This will take care of getting the most recent status. If most recent is "CREATED" then even if it 2 years old
            -- it will not insert anything and further below I am ensuring that by checking for "CREATED"
            SELECT A1.law_firm, A1.case_id, A1.person_id, A1.status, date(max(created_at)) as mcreated_at
            FROM channel_notification_staging A1,
                 (SELECT law_firm, case_id, person_id, max(created_at) as mCcreated_at
                  FROM channel_notification_staging
                       -- WHERE status = 'CREATED'
                  group by law_firm, case_id, person_id) A2
            where A1.law_firm = A2.law_firm
              and A1.case_id = A2.case_id
              and A1.person_id = A2.person_id
              AND A1.created_at = A2.mCcreated_at
            group by law_firm, case_id, person_id) e
                           on (A.law_firm = e.law_firm and A.icase = e.case_id and A.person = e.person_id)
            -- avoiding translation within cursor for easy maintenance
                 left join translation t
                           on (A.document_type = t.default_text and coalesce(c.language, 'en') = t.language)
        where A.document_status = 'TO_BE_UPLOADED'
          and d.case_status = 'OPEN'
          and coalesce(cp.name, coalesce(B.name, 'No')) =
              'DOCUMENT_REMINDER_EMAIL_IN_DAYS'            -- first check case preference and then firm-preference
          and coalesce(e.status, 'Yes') <> 'CREATED'       -- ensure even if most recent is created and 2 years old for example
          -- using nested coalesce to get reminder-days given reminder of Yes or No is qualified above
          and DATEDIFF(CURRENT_DATE, coalesce(DATE(mcreated_at), DATE_SUB(current_date, INTERVAL 31 DAY))) >=
              coalesce(cp.value, coalesce(B.value, 0))
          and coalesce(c.email, '') <> ''

          -- if email is null there is nothing to insert
          -- and A.icase in(405,412)
          and coalesce(cp.value, coalesce(B.value, 0)) > 0 -- 12/22/2019 - Added where clause to omit records with notification_days set to 0.
        order by B.law_firm_id, icase, person;
    -- declare NOT FOUND handler
    DECLARE CONTINUE HANDLER
        FOR NOT FOUND SET finished = 1;
    OPEN cur_channel_notification;
    lnotification:
    LOOP
        --
        FETCH cur_channel_notification INTO vcursor_break,vlaw_firm_id,vicase,vperson_id, vlanguage_preference,
            vdocument, vnotification_days, vemailAddress,vdescription,vphone,vdocument_uuid,vcase_uuid;
        IF finished = 1 then
            -- execute the final set i.e. insert the last record group and also make sure cursor is not empty by using vllaw_firm_id <> 0
            if Vllaw_firm_id <> 0 then
                insert into channel_notification_staging
                (law_firm, case_id, person_id, language, last_modified_at, from_address, to_address, cc_address,
                 bcc_address, subject, content, channel, header, footer,phone,document_uuid)
                VALUES (vllaw_firm_id, vlicase, vlperson_id, vllanguage_preference, CURRENT_TIMESTAMP, 'CampLegal',
                        vlemailaddress, 'law_firm', 'system_notification@camplegal.com', 'Document Reminder',
                        VDOCUMENT_STRING, 'Email',
                        'Please upload the following list of documents. If you have any questions or concerns, feel free to contact us. Thank you!',vphone,vdocument_uuid);
                commit;
            end if;
            LEAVE lnotification;
        END IF;
        IF Vcursor_break_last_val = '0' OR Vcursor_break_last_val = Vcursor_break THEN -- if first row fetch or no break in cursor break-key
            IF Vcursor_break_last_val = '0' THEN -- start with cursor fetch since first record in cursor-break group will be empty
                SET VDOCUMENT_STRING =
                        CONCAT('<p class="document-type">', VDOCUMENT, '</p><p class="description">', Vdescription,
                               '</p>','<p><a href="https://client.camplegal.com/document_requests#?documentRequestId=',vcase_uuid,'> Upload</a>');
            ELSEIF Vcursor_break_last_val = Vcursor_break THEN
                SET VDOCUMENT_STRING =
                        CONCAT('<p class="document-type">', VDOCUMENT, '</p><p class="description">', Vdescription,
                               '</p>','<p><a href="https://client.camplegal.com/document_requests#?documentRequestId=',vcase_uuid,'> Upload</a>');
            END IF;
        END IF;
        IF Vcursor_break_last_val <> '0' AND Vcursor_break_last_val <> Vcursor_break THEN -- this means that cursor fetched alteast one group and there is a break
            insert into channel_notification_staging
            (law_firm, case_id, person_id, language, last_modified_at, from_address, to_address, cc_address,
             bcc_address, subject, content, channel, header, footer)
            VALUES (vllaw_firm_id, vlicase, vlperson_id, vllanguage_preference, CURRENT_TIMESTAMP, 'CampLegal',
                    vlemailaddress, 'law_firm', 'system_notification@camplegal.com', 'Document Reminder',
                    VDOCUMENT_STRING, 'Email',
                    'Please upload the following list of documents. If you have any questions or concerns, feel free to contact us. Thank you!');
            commit;
            SET VDOCUMENT_STRING =
                    CONCAT('<p class="document-type">', Vdocument, '</p>'); -- reset this string with where the cursor is now
        END IF;
        SET Vcursor_break_last_val = Vcursor_break;
        -- set prev cursor values
        SET Vllaw_firm_id = Vlaw_firm_id;
        SET Vlicase = Vicase;
        SET Vlperson_id = Vperson_id;
        SET Vllanguage_preference = Vlanguage_preference;
        SET Vldocument = Vdocument;
        SET V1description = Vdescription;
        SET Vlnotification_days = Vnotification_days;
        SET VlemailAddress = VemailAddress;
    END LOOP lnotification;
    CLOSE cur_channel_notification;
END;

