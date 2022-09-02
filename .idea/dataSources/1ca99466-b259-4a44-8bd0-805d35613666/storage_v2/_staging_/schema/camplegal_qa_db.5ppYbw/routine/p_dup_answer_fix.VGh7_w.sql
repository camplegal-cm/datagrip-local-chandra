create
    definer = root@localhost procedure p_dup_answer_fix(IN p_law_firm bigint, IN p_case_id bigint, IN p_petitioner_id bigint)
begin
declare c_lawfirm cursor for select * from law_firm;
open c_lawfirm;

close c_lawfirm;
delete
    a
from answer a
         inner join
     (select id, question_id, created_at /*case_id,petitioner_id,question_id,created_at*/
      from answer a
      where law_firm = p_law_firm
        and case_id = p_case_id
        and petitioner_id = p_petitioner_id
      group by case_id, petitioner_id, question_id
      having count(*) > 1
                 not in
             (select max(id) /*case_id,petitioner_id,question_id,created_at*/
              from answer
              where law_firm = p_law_firm
                and case_id = p_case_id
                and petitioner_id = p_petitioner_id
              group by case_id, petitioner_id, question_id
              having count(*) > 1)) as temp
     on a.id = temp.id
where law_firm = p_law_firm
  and case_id = p_case_id
  and petitioner_id = p_petitioner_id;

SELECT 'Number of Rows Deleted' || ROW_COUNT() as deleted_row_count;
end;

