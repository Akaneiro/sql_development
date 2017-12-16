CREATE OR REPLACE PACKAGE hr.session_pkg IS
    TYPE type_subjects IS
        TABLE OF NUMBER;
    PROCEDURE getstudents;

    PROCEDURE getsubjects;

    PROCEDURE addstudent(student_id NUMBER, student_name VARCHAR2, student_group VARCHAR2);

END session_pkg;
/

CREATE OR REPLACE PACKAGE BODY session_pkg AS
    /* Добавление студента */
    PROCEDURE addstudent(student_id NUMBER, student_name VARCHAR2, student_group VARCHAR2)
    AS
    BEGIN
    INSERT INTO HR.STUDENTS(HR.STUDENTS.STUDENT_ID, HR.STUDENTS.STUDENT_NAME, HR.STUDENTS.STUDENT_GROUP)
    VALUES(student_id, student_name, student_group);
    END addstudent;

    /* список студентов */

    PROCEDURE getstudents
        AS
    BEGIN
    -- TODO: Implementation required for PROCEDURE TEST_PKG.get_students
        DECLARE
            CURSOR students_list IS SELECT
                *
                                    FROM
                hr.students;

        BEGIN
            FOR student IN students_list LOOP
                dbms_output.put_line(student.student_id
                || ' | '
                || student.student_name
                || ' | '
                || student.student_group
                || ' | '
                || student.student_grant);
            END LOOP;

        END;
    END getstudents;
  
  /* список предметов */

    PROCEDURE getsubjects
        AS
    BEGIN
    -- TODO: Implementation required for PROCEDURE TEST_PKG.get_students
        DECLARE
            CURSOR subjects_list IS SELECT
                *
                                    FROM
                hr.subjects;

        BEGIN
            FOR subject IN subjects_list LOOP
                dbms_output.put_line(subject.subject_name
                || ' | '
                || subject.subject_date
                || ' | '
                || subject.subject_reporting_form
                || ' | '
                || subject.subject_group
                || ' | '
                || subject.subject_teacher_name);
            END LOOP;

        END;
    END getsubjects;

END session_pkg;
/