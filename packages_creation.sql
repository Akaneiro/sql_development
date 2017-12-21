create or replace PACKAGE session_pkg IS
    TYPE student_in_list IS RECORD ( s_id NUMBER(7,0),
    s_name VARCHAR2(40 BYTE),
    s_group VARCHAR2(7 BYTE),
    s_grant NUMBER(7,2) );
    PROCEDURE getstudents (
        sort_by_group NUMBER
    );

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

    PROCEDURE getseveralstudentsgrades (
        s_group VARCHAR2
    );

    PROCEDURE deleteemptygroups;

    PROCEDURE passexam (
        s_id         NUMBER,
        subj_name    VARCHAR2,
        subj_grade   NUMBER
    );
    
    PROCEDURE sessionlength;

END session_pkg;
/

create or replace PACKAGE BODY session_pkg AS
    /* Добавление студента */

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

            iterator           INTEGER := 1;
        BEGIN
            INSERT INTO students (
                students.student_id,
                students.student_name,
                students.student_group
            ) VALUES (
                student_id,
                student_name,
                student_group
            );

            FOR subject IN subjects_list LOOP
                dbms_output.put_line(3);
                student_subjects.extend ();
                student_subjects(iterator) := type_student_subject(subject.subject_name,subject.subject_reporting_form,NULL);

                iterator := iterator + 1;
            END LOOP;

            INSERT INTO recordbooks (
                recordbooks.student_id,
                recordbooks.student_subjects
            ) VALUES (
                student_id,
                student_subjects
            );

        END;
    END addstudent;

    /* Добавление предмета */

    PROCEDURE addsubject (
        subject_name             VARCHAR2,
        subject_date             DATE,
        subject_reporting_form   VARCHAR2,
        subject_group            VARCHAR2,
        subject_teacher_name     VARCHAR2
    )
        AS
    BEGIN
        DECLARE
            CURSOR group_cursor (
                stdnt_group VARCHAR2
            ) IS SELECT
                students.student_id
                 FROM
                students
                 WHERE
                students.student_group = stdnt_group;

            CURSOR recordbooks_cursor (
                s_id NUMBER
            ) IS SELECT
                recordbooks.student_subjects
                 FROM
                recordbooks
                 WHERE
                recordbooks.student_id = s_id;

            s_id       NUMBER;
            subjects   type_subjects;
        BEGIN
            INSERT INTO subjects (
                subjects.subject_name,
                subjects.subject_date,
                subjects.subject_reporting_form,
                subjects.subject_group,
                subjects.subject_teacher_name
            ) VALUES (
                subject_name,
                subject_date,
                subject_reporting_form,
                subject_group,
                subject_teacher_name
            );

            OPEN group_cursor(subject_group);
            LOOP
                FETCH group_cursor INTO s_id;
                EXIT WHEN group_cursor%notfound;
                OPEN recordbooks_cursor(s_id);
                FETCH recordbooks_cursor INTO subjects;
                subjects.extend;
                subjects(subjects.last) := type_student_subject(subject_name,subject_reporting_form,NULL);
                UPDATE recordbooks
                    SET
                        student_subjects = subjects
                WHERE
                    student_id = s_id;

                CLOSE recordbooks_cursor;
            END LOOP;

            CLOSE group_cursor;
        END;
    END addsubject;

    /* Отчисление студента */

    PROCEDURE firestudent (
        s_id NUMBER
    )
        AS
    BEGIN
        DECLARE
            student_subjects   type_subjects := type_subjects ();
            CURSOR subjects_list IS SELECT
                student_subjects
                                    FROM
                recordbooks
                                    WHERE
                recordbooks.student_id = s_id;

            iterator           INTEGER := 1;
            need_fire          BOOLEAN;
            subject            type_student_subject;
        BEGIN
            need_fire := false;
            OPEN subjects_list;
            FETCH subjects_list INTO student_subjects;
                -- dbms_output.put_line(student_subjects.COUNT);
            LOOP
                subject := student_subjects(iterator);
                dbms_output.put_line(subject.subject_grade);
                IF
                    ( subject.subject_grade IS NULL )
                THEN
                    need_fire := true;
                END IF;
                -- dbms_output.put_line(3);
                iterator := iterator + 1;
                EXIT WHEN iterator > student_subjects.count OR need_fire = true;
            END LOOP;

            CLOSE subjects_list;
            IF
                ( need_fire = true )
            THEN
                DELETE FROM students
                WHERE
                    students.student_id = s_id;

            END IF;

        END;
    END firestudent;

    /* список студентов */

    PROCEDURE getstudents (
        sort_by_group NUMBER
    )
        AS
    BEGIN
        DECLARE
            TYPE cur IS REF CURSOR;
            students_list   cur;
            student         student_in_list;
        BEGIN
            IF
                ( sort_by_group = 1 )
            THEN
                OPEN students_list FOR 'Select * from students ORDER BY students.student_group';

            ELSE
                OPEN students_list FOR 'Select * from students';

            END IF;

            LOOP
                FETCH students_list INTO student;
                EXIT WHEN students_list%notfound;
                dbms_output.put_line(student.s_id
                || ' | '
                || student.s_name
                || ' | '
                || student.s_group
                || ' | '
                || student.s_grant);

            END LOOP;

        END;
    END getstudents;

    /* список предметов */

    PROCEDURE getsubjects
        AS
    BEGIN
        DECLARE
            CURSOR subjects_list IS SELECT
                *
                                    FROM
                subjects;

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

    /* Успеваемость студента */

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
                students
                               WHERE
                students.student_id = s_id;

            CURSOR s_grades IS SELECT
                student_subjects
                               FROM
                recordbooks
                               WHERE
                recordbooks.student_id = s_id;

            index_max   PLS_INTEGER;
            g_index     PLS_INTEGER;
        BEGIN
            FOR student IN students LOOP
                dbms_output.put_line('Успеваемость студента '
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
    
    -- Успеваемость студентов группы или всего университета

    PROCEDURE getseveralstudentsgrades (
        s_group VARCHAR2
    )
        AS
    BEGIN
        DECLARE
            TYPE cur IS REF CURSOR;
            students_list   cur;
            student         student_in_list;
            CURSOR grades_cursor (
                s_id NUMBER
            ) IS SELECT
                recordbooks.student_subjects
                 FROM
                recordbooks
                 WHERE
                recordbooks.student_id = s_id;

            iterator        NUMBER;
            subjects        type_subjects;
        BEGIN
            IF
                ( s_group IS NULL )
            THEN
                OPEN students_list FOR SELECT
                    *
                                       FROM
                    students
                ORDER BY
                    students.student_group,
                    students.student_id;

            ELSE
                OPEN students_list FOR SELECT
                    *
                                       FROM
                    students
                                       WHERE
                    students.student_group = s_group;

            END IF;

            LOOP
                FETCH students_list INTO student;
                EXIT WHEN students_list%notfound;
                dbms_output.put_line(student.s_id
                || ' | '
                || student.s_name
                || ' | '
                || student.s_group);

                FOR grades IN grades_cursor(student.s_id) LOOP
                    subjects := grades.student_subjects;
                    FOR iterator IN 1..subjects.count LOOP
                        dbms_output.put_line(subjects(iterator).subject_name
                        || ' | '
                        || subjects(iterator).subject_reporting_form
                        || ' | '
                        || subjects(iterator).subject_grade);
                    END LOOP;

                END LOOP;

            END LOOP;

        END;
    END getseveralstudentsgrades;

    -- Удаление пустых групп

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

    PROCEDURE passexam (
        s_id         NUMBER,
        subj_name    VARCHAR2,
        subj_grade   NUMBER
    )
        AS
    BEGIN
        DECLARE
            CURSOR recordbook_cursor IS SELECT
                recordbooks.student_subjects
                                        FROM
                recordbooks
                                        WHERE
                recordbooks.student_id = s_id;

            iterator        NUMBER := 1;
            subjects        type_subjects;
            can_pass_exam   BOOLEAN;
        BEGIN
            OPEN recordbook_cursor;
            FETCH recordbook_cursor INTO subjects; -- Запись одна
            CLOSE recordbook_cursor;
            LOOP
                EXIT WHEN iterator > subjects.last;
                IF
                    ( subjects(iterator).subject_name = subj_name )
                THEN
                    IF
                        ( subjects(iterator).subject_grade IS NULL OR subjects(iterator).subject_grade < 3 )
                    THEN
                        can_pass_exam := true;
                        EXIT;
                    END IF;

                END IF;

                iterator := iterator + 1;
            END LOOP;

            IF
                can_pass_exam = true
            THEN
                subjects(iterator).subject_grade := subj_grade;
                UPDATE recordbooks
                    SET
                        student_subjects = subjects
                WHERE
                    student_id = s_id;

            ELSE
                dbms_output.put_line('Нельзя пересдать данный предмет!');
            END IF;

        END;
    END passexam;

    PROCEDURE sessionlength
        AS
    BEGIN
        DECLARE
            CURSOR group_cursor IS SELECT DISTINCT
                subjects.subject_group
                                   FROM
                subjects;

            days         NUMBER;
            student_group   VARCHAR2(7 BYTE);
            CURSOR group_session_cursor (
                subj_group VARCHAR2
            ) IS SELECT
                MAX(subject_date) - MIN(subject_date)
                 FROM
                subjects
                 WHERE
                subject_group = student_group;

        BEGIN
            FOR stud_group IN group_cursor LOOP
                student_group := stud_group.subject_group;
                dbms_output.put_line(student_group
                || ': ');
                OPEN group_session_cursor(student_group);
                FETCH group_session_cursor INTO days;
                dbms_output.put_line(days||' дней');
                CLOSE group_session_cursor;
            END LOOP;

        END;
    END sessionlength;

END session_pkg;