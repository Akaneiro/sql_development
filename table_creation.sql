/*//////////////////////////////////////////////////////////////////////////////
// �������� ������� ���������
////////////////////////////////////////////////////////////////////////////////
*/

CREATE TABLE students (
    student_id      NUMBER(7,0) NOT NULL,
    student_name    VARCHAR2(40 BYTE) NOT NULL,
    student_group   VARCHAR2(7 BYTE) NOT NULL,
    student_grant   NUMBER(7,2) DEFAULT 0 NOT NULL
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

CREATE SEQUENCE students_seq START WITH 1000000 INCREMENT BY 1 NOMAXVALUE;

CREATE OR REPLACE TRIGGER students_id_trg BEFORE
    INSERT ON students
    FOR EACH ROW
BEGIN
    IF
        :new.student_id IS NULL
    THEN
        SELECT
            students_seq.NEXTVAL
        INTO
            :new.student_id
        FROM
            dual;

    END IF;
END;
/
CREATE OR REPLACE TRIGGER student_after_insert AFTER
    INSERT ON students
    FOR EACH ROW
DECLARE
    student_subjects   type_subjects := type_subjects ();
    CURSOR subjects_list (
        s_group VARCHAR2
    ) IS SELECT
        *
         FROM
        subjects
         WHERE
        subjects.subject_group = s_group;

    s_id               NUMBER;
BEGIN
    FOR subject IN subjects_list(:new.student_group) LOOP
        student_subjects.extend ();
        student_subjects(student_subjects.last) := type_student_subject(subject.subject_name,subject.subject_reporting_form,NULL);

    END LOOP;

    INSERT INTO recordbooks (
        recordbooks.student_id,
        recordbooks.student_subjects
    ) VALUES (
        :new.student_id,
        student_subjects
    );

END;
/

/*
////////////////////////////////////////////////////////////////////////////////
// �������� ������� �������
////////////////////////////////////////////////////////////////////////////////
*/

CREATE TABLE recordbooks (
    student_id         NUMBER(7,0) NOT NULL,
    student_subjects   type_subjects
)
NESTED TABLE student_subjects STORE AS nested_student_subjects;

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

CREATE UNIQUE INDEX uq_subjects_same_pair ON
    subjects ( subject_name,
    subject_group );

CREATE UNIQUE INDEX uq_subjects_same_day ON
    subjects ( subject_group,
    subject_date );

ALTER TABLE subjects
    ADD CONSTRAINT reporting_form_value CHECK ( "SUBJECT_REPORTING_FORM" IN (
        '�����',
        '�������'
    ) );

create or replace TRIGGER subjects_after_insert AFTER
    INSERT ON subjects
    FOR EACH ROW
DECLARE
    CURSOR student_cursor (
        s_group VARCHAR2
    ) IS SELECT
        student_id,
        student_name,
        student_subjects
         FROM
        (
            SELECT
                students.student_id student_id,
                students.student_name student_name,
                students.student_group student_group,
                students.student_grant student_grant,
                recordbooks.student_id student_id_0,
                recordbooks.student_subjects student_subjects
            FROM
                students
                INNER JOIN recordbooks ON students.student_id = recordbooks.student_id
        ) s_students
         WHERE
        s_students.student_group = s_group;

    subjects   student_cursor%rowtype;
BEGIN
    OPEN student_cursor(:new.subject_group);
    LOOP
        FETCH student_cursor INTO subjects;
        EXIT WHEN student_cursor%notfound;
        subjects.student_subjects.extend;
        subjects.student_subjects(subjects.student_subjects.last) := type_student_subject(:new.subject_name,:new.subject_reporting_form,NULL
);

        UPDATE recordbooks
            SET
                student_subjects = subjects.student_subjects
        WHERE
            student_id = subjects.student_id;

    END LOOP;

    CLOSE student_cursor;
END;
/

CREATE OR REPLACE TRIGGER subjects_before_insert BEFORE
    INSERT ON subjects
    FOR EACH ROW
DECLARE
    credit_count    NUMBER;
    exam_count      NUMBER;
    invalid_credit_count EXCEPTION;
    PRAGMA exception_init ( invalid_credit_count,-20098 );
    invalid_exams_count EXCEPTION;
    PRAGMA exception_init ( invalid_exams_count,-20099 );
    invalid_exams_date EXCEPTION;
    PRAGMA exception_init ( invalid_exams_date,-20097 );
    max_exam_date   DATE;
BEGIN
    IF
        (:new.subject_reporting_form = '�����' )
    THEN
        SELECT
            COUNT(*)
        INTO
            credit_count
        FROM
            subjects
        WHERE
            subjects.subject_reporting_form =:new.subject_reporting_form;

        SELECT
            MIN(subjects.subject_date)
        INTO
            max_exam_date
        FROM
            subjects
        WHERE
            subjects.subject_group =:new.subject_group
            AND   subjects.subject_reporting_form = '�������';

        IF
            credit_count > 5
        THEN
            RAISE invalid_credit_count;
        END IF;
        IF
            max_exam_date <:new.subject_date
        THEN
            RAISE invalid_exams_date;
        END IF;
    END IF;

    IF
        (:new.subject_reporting_form = '�������' )
    THEN
        SELECT
            COUNT(*)
        INTO
            exam_count
        FROM
            subjects
        WHERE
            subjects.subject_reporting_form =:new.subject_reporting_form;

        SELECT
            MAX(subjects.subject_date)
        INTO
            max_exam_date
        FROM
            subjects
        WHERE
            subjects.subject_group =:new.subject_group
            AND   subjects.subject_reporting_form = '�����';

        IF
            exam_count > 4
        THEN
            RAISE invalid_exams_count;
        END IF;
        IF
            max_exam_date >:new.subject_date
        THEN
            RAISE invalid_exams_date;
        END IF;
    END IF;

END;
/