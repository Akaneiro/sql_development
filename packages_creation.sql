CREATE OR REPLACE PACKAGE session_pkg IS
    PROCEDURE getstudents;

    PROCEDURE getsubjects;

    PROCEDURE addstudent (
        student_id      NUMBER,
        student_name    VARCHAR2,
        student_group   VARCHAR2
    );

    PROCEDURE addsubject (
        subject_name             VARCHAR2,
        subject_date             DATE,
        subject_reporting_form   VARCHAR2,
        subject_group            VARCHAR2,
        subject_teacher_name     VARCHAR2
    );

    PROCEDURE firestudent (
        s_id NUMBER
    );

    PROCEDURE getstudentgrades (
        s_id NUMBER
    );

    PROCEDURE deleteemptygroups;

END session_pkg;
/

CREATE OR REPLACE PACKAGE BODY session_pkg AS
    /* ���������� �������� */

    PROCEDURE addstudent (
        student_id      NUMBER,
        student_name    VARCHAR2,
        student_group   VARCHAR2
    )
        AS
    BEGIN
        DECLARE
            student_subjects   type_subjects := type_subjects ();
            CURSOR subjects_list IS SELECT
                *
                                    FROM
                subjects
                                    WHERE
                subjects.subject_group = student_group;

            iterator          INTEGER := 1;
        BEGIN
            INSERT INTO hr.students (
                hr.students.student_id,
                hr.students.student_name,
                hr.students.student_group
            ) VALUES (
                student_id,
                student_name,
                student_group
            );

            FOR subject IN subjects_list LOOP
                student_subjects.extend ();
                student_subjects(iterator) := type_student_subject(subject.subject_name,subject.subject_reporting_form, NULL);
                iterator := iterator + 1;
            END LOOP;
            
            INSERT INTO recordbooks(recordbooks.student_id, recordbooks.student_subjects)
            VALUES (student_id, student_subjects);
        END;
    END addstudent;

    /* ���������� �������� */

    PROCEDURE addsubject (
        subject_name             VARCHAR2,
        subject_date             DATE,
        subject_reporting_form   VARCHAR2,
        subject_group            VARCHAR2,
        subject_teacher_name     VARCHAR2
    )
        AS
    BEGIN
        INSERT INTO hr.subjects (
            hr.subjects.subject_name,
            hr.subjects.subject_date,
            hr.subjects.subject_reporting_form,
            hr.subjects.subject_group,
            hr.subjects.subject_teacher_name
        ) VALUES (
            subject_name,
            subject_date,
            subject_reporting_form,
            subject_group,
            subject_teacher_name
        );

    END addsubject;

    /* ���������� �������� */

    PROCEDURE firestudent (
        s_id NUMBER
    )
        AS
    BEGIN
        DELETE FROM hr.students
        WHERE
            hr.students.student_id = s_id;

    END firestudent;

    /* ������ ��������� */

    PROCEDURE getstudents
        AS
    BEGIN
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

    /* ������ ��������� */

    PROCEDURE getsubjects
        AS
    BEGIN
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

    /* ������������ �������� */

    PROCEDURE getstudentgrades (
        s_id NUMBER
    )
        AS
    BEGIN
        DECLARE
            CURSOR students IS SELECT
                student_name,
                student_group
                               FROM
                hr.students
                               WHERE
                hr.students.student_id = s_id;

            CURSOR s_grades IS SELECT
                student_subjects
                               FROM
                hr.recordbooks
                               WHERE
                hr.recordbooks.student_id = s_id;

            index_max   PLS_INTEGER;
            g_index     PLS_INTEGER;
        BEGIN
            FOR student IN students LOOP
                dbms_output.put_line('������������ �������� '
                || student.student_name);
            END LOOP;

            FOR grades IN s_grades LOOP
                index_max := grades.student_subjects.count;
                FOR g_index IN 1..index_max LOOP
                    dbms_output.put_line(grades.student_subjects(g_index).subject_name
                    || ':'
                    || grades.student_subjects(g_index).subject_name
                    || '/'
                    || grades.student_subjects(g_index).subject_grade);
                END LOOP;

            END LOOP;

        END;
    END getstudentgrades;

    -- �������� ������ �����

    PROCEDURE deleteemptygroups
        AS
    BEGIN
        DECLARE
            CURSOR s_groups IS SELECT DISTINCT
                subjects.subject_group
                               FROM
                subjects;

            CURSOR group_cursor (
                stdnt_group VARCHAR2
            ) IS SELECT
                students.student_group
                 FROM
                students
                 WHERE
                students.student_group = stdnt_group;

            stud   group_cursor%rowtype;
        BEGIN
            FOR s_group IN s_groups LOOP
                OPEN group_cursor(s_group.subject_group);
                FETCH group_cursor INTO stud;
                IF
                    group_cursor%rowcount = 0
                THEN
                    DELETE FROM subjects
                    WHERE
                        subjects.subject_group = s_group.subject_group;

                END IF;

                CLOSE group_cursor;
            END LOOP;

        END;
    END deleteemptygroups;

END session_pkg;