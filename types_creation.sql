-- Типы 
CREATE OR REPLACE TYPE type_student_subject AS OBJECT (
    subject_name             VARCHAR2(20),
    subject_reporting_form   VARCHAR2(20),
    subject_grade            CHAR
);
/

CREATE OR REPLACE TYPE type_subjects AS
    TABLE OF type_student_subject;
/