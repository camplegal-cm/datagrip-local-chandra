create
    definer = root@localhost procedure proc_copy_contact_addresses(IN p_law_firm bigint, IN p_from_person_id bigint, IN p_to_person_id bigint)
begin
    delete from person_previous_address where law_firm_id = p_law_firm and person_id = p_to_person_id;
    insert into person_previous_address(person_id, law_firm_id, address_line1, address_line2_type, address_line2, city,
                                        province, state, zip, postal_code, county, country, start_date, end_date,
                                        created_at, start_date_type, end_date_type)
    select p_to_person_id,
           p_law_firm,
           address_line1,
           address_line2_type,
           address_line2,
           city,
           province,
           state,
           zip,
           postal_code,
           county,
           country,
           start_date,
           end_date,
           created_at,
           start_date_type,
           end_date_type
    from person_previous_address
    where law_firm_id = p_law_firm
      and person_id = p_from_person_id;

    UPDATE person toPerson , (SELECT * from person where law_firm = p_law_firm and id = p_from_person_id) fromPerson
    set toPerson.in_care_of_name_mailing     = fromPerson.in_care_of_name_mailing,
        toPerson.address_line1_mailing       = fromPerson.address_line1_mailing,
        toPerson.address_line2_mailing       = fromPerson.address_line2_mailing,
        toPerson.address_line2_type_mailing  = fromPerson.address_line2_type_mailing,
        toPerson.city_mailing                = fromPerson.city_mailing,
        toPerson.county_mailing              = fromPerson.county_mailing,
        toPerson.state_mailing               = fromPerson.state_mailing,
        toPerson.zip_mailing                 = fromPerson.zip_mailing,
        toPerson.postal_code_mailing         = fromPerson.postal_code_mailing,
        toPerson.province_mailing            = fromPerson.province_mailing,
        toPerson.country_mailing             = fromPerson.country_mailing,
        toPerson.address_line1_physical      = fromPerson.address_line1_physical,
        toPerson.address_line2_physical      = fromPerson.address_line2_physical,
        toPerson.address_line2_type_physical = fromPerson.address_line2_type_physical,
        toPerson.city_physical               = fromPerson.city_physical,
        toPerson.county_physical             = fromPerson.county_physical,
        toPerson.state_physical              = fromPerson.state_physical,
        toPerson.zip_physical                = fromPerson.zip_physical,
        toPerson.postal_code_physical        = fromPerson.postal_code_physical,
        toPerson.province_physical           = fromPerson.province_physical,
        toPerson.country_physical            = fromPerson.country_physical,
        toPerson.start_date                  = fromPerson.start_date

    WHERE toPerson.law_firm = p_law_firm
      and toPerson.id = p_to_person_id;
end;

