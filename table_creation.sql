/*//////////////////////////////////////////////////////////////////////////////
// �������� ������� ���������
////////////////////////////////////////////////////////////////////////////////
*/

CREATE TABLE students (
    student_id      NUMBER(7,0) NOT NULL,
    student_name    VARCHAR2(40 BYTE) NOT NULL,
    student_group   VARCHAR2(7 BYTE) NOT NULL,
    student_grant   NUMBER(7,2) DEFAULT 0
);

ALTER TABLE students ADD CONSTRAINT students_id_pk PRIMARY KEY ( student_id ) ENABLE;

ALTER TABLE students
    ADD CONSTRAINT student_name_nn CHECK ( "STUDENT_NAME" IS NOT NULL ) ENABLE;

ALTER TABLE students
    ADD CONSTRAINT student_group_nn CHECK ( "STUDENT_GROUP" IS NOT NULL ) ENABLE;

COMMENT ON COLUMN students.student_id IS
    '����� ������������� ������';

COMMENT ON COLUMN students.student_name IS
    '��� ��������';

COMMENT ON COLUMN students.student_group IS
    '������ ��������';

COMMENT ON COLUMN students.student_grant IS
    '��������� ��������';
    
CREATE SEQUENCE students_seq
START WITH 1000000 
INCREMENT BY 1 
NOMAXVALUE;
    
create or replace trigger students_id_trg
before insert on students
for each row
begin
  if :new.student_id is null then
    select students_seq.nextval into :new.student_id from dual;
  end if;
end;

/*
////////////////////////////////////////////////////////////////////////////////
// �������� ������� �������
////////////////////////////////////////////////////////////////////////////////
*/

CREATE TABLE recordbooks (
    student_id   NUMBER(7,0) NOT NULL,
    student_subjects type_subjects
)NESTED TABLE student_subjects STORE AS nested_student_subjects;

ALTER TABLE recordbooks
    ADD CONSTRAINT student_id_fk FOREIGN KEY ( student_id )
        REFERENCES students ( student_id )
        ON DELETE CASCADE;

COMMENT ON COLUMN recordbooks.student_id IS
    '����� ������������� ������';
    
COMMENT ON COLUMN recordbooks.student_subjects IS
    '������ ��������� ��� �����';

/*
////////////////////////////////////////////////////////////////////////////////
// �������� ������� ���������
////////////////////////////////////////////////////////////////////////////////
*/

CREATE TABLE subjects (
    subject_name             VARCHAR2(40 BYTE) NOT NULL,
    subject_date             DATE NOT NULL,
    subject_reporting_form   VARCHAR2(20) NOT NULL,
    subject_group            VARCHAR2(7 BYTE) NOT NULL,
    subject_teacher_name     VARCHAR2(40) NOT NULL
);

ALTER TABLE subjects
    ADD CONSTRAINT subject_name_nn CHECK ( "SUBJECT_NAME" IS NOT NULL ) ENABLE;

ALTER TABLE subjects
    ADD CONSTRAINT subject_date_nn CHECK ( "SUBJECT_DATE" IS NOT NULL ) ENABLE;

ALTER TABLE subjects
    ADD CONSTRAINT subject_reporting_form_nn CHECK ( "SUBJECT_REPORTING_FORM" IS NOT NULL ) ENABLE;

ALTER TABLE subjects
    ADD CONSTRAINT subject_group_nn CHECK ( "SUBJECT_GROUP" IS NOT NULL ) ENABLE;

ALTER TABLE subjects
    ADD CONSTRAINT subject_teacher_name_nn CHECK ( "SUBJECT_TEACHER_NAME" IS NOT NULL ) ENABLE;
    
CREATE UNIQUE INDEX uq_subjects_same_pair
    ON subjects(subject_name, subject_group);
    
CREATE UNIQUE INDEX uq_subjects_same_day
    ON subjects(subject_group, subject_date);
    
ALTER TABLE subjects 
    ADD CONSTRAINT reporting_form_value CHECK ("SUBJECT_REPORTING_FORM" IN ('�����', '�������'));