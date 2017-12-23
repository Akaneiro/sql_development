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
        subj_grade   CHAR
    );

    PROCEDURE sessionlength;

    PROCEDURE movestudent (
        s_id NUMBER,
        s_group VARCHAR2
    );

    PROCEDURE setgrants (
        standard_grant NUMBER,
        upper_grant NUMBER
    );
    
    PROCEDURE getaveragegrants;
    
    PROCEDURE getteachersgrades;

END session_pkg;
/

CREATE OR REPLACE PACKAGE BODY session_pkg AS
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
                EXIT WHEN iterator > student_subjects.count OR need_fire = true;
                subject := student_subjects(iterator);
                -- dbms_output.put_line(subject.subject_grade);
                IF
                    ( subject.subject_grade IS NOT NULL OR subject.subject_grade = 'Y' OR to_number(subject.subject_grade) <> 2 )
                THEN
                    need_fire := false;
                ELSE
                    need_fire := true;
                END IF;

                iterator := iterator + 1;
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

            CLOSE students_list;
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
                    || ': '
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

            CLOSE students_list;
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
        subj_grade   CHAR
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
            invalid_grade_exc EXCEPTION;
            invalid_subject_exc EXCEPTION;
            grade           CHAR(1);
        BEGIN
            OPEN recordbook_cursor;
            FETCH recordbook_cursor INTO subjects; -- Запись одна
            CLOSE recordbook_cursor;
            LOOP
                EXIT WHEN iterator > subjects.last;
                IF
                    subjects(iterator).subject_name = subj_name
                THEN
                    grade := subjects(iterator).subject_grade;
                    IF
                        grade IS NULL OR grade = 'N'
                    THEN
                        can_pass_exam := true;
                    ELSIF grade = 'Y' OR to_number(grade) > 3 THEN
                        can_pass_exam := false;
                    END IF;

                    EXIT;
                END IF;

                iterator := iterator + 1;
            END LOOP;

            IF
                iterator > subjects.last
            THEN
                RAISE invalid_subject_exc;
            END IF;
            IF
                subjects(iterator).subject_reporting_form = 'зачет' AND subj_grade NOT IN (
                    'Y',
                    'N'
                ) OR subjects(iterator).subject_reporting_form = 'экзамен' AND subj_grade NOT IN (
                    '2',
                    '3',
                    '4',
                    '5'
                )
            THEN
                RAISE invalid_grade_exc;
            END IF;

            IF
                can_pass_exam = true
            THEN
                grade := substr(subj_grade,1,1);
                subjects(iterator).subject_grade := grade;
                UPDATE recordbooks
                    SET
                        student_subjects = subjects
                WHERE
                    student_id = s_id;

            ELSE
                dbms_output.put_line('Нельзя пересдать данный предмет!');
            END IF;

        EXCEPTION
            WHEN invalid_grade_exc THEN
                dbms_output.put_line('Неверно введена оценка');
            WHEN invalid_subject_exc THEN
                dbms_output.put_line('Такого предмета не существует, увы');
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

            days            NUMBER;
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
                dbms_output.put_line(days
                || ' дней');
                CLOSE group_session_cursor;
            END LOOP;

        END;
    END sessionlength;

    PROCEDURE movestudent (
        s_id NUMBER,
        s_group VARCHAR2
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

            CURSOR subjects_cursor IS SELECT
                *
                                      FROM
                subjects
                                      WHERE
                subjects.subject_group = s_group;

            subjects_list_new   type_subjects := type_subjects ();
            subjects_list_old   type_subjects;
            recordbook_item     type_student_subject;
            iterator            NUMBER := 1;
            subject_contains    BOOLEAN := false;
        BEGIN
        -- считали старую зачетку
            OPEN recordbook_cursor;
            FETCH recordbook_cursor INTO subjects_list_old;
            CLOSE recordbook_cursor;
            -- пробегаемся по списку предметов...
            FOR subject_item IN subjects_cursor LOOP
                subject_contains := false;
                -- и по списку в старой зачетке
                FOR iterator IN 1..subjects_list_old.last LOOP
                    IF
                        subjects_list_old(iterator).subject_name = subject_item.subject_name
                    THEN
                        subject_contains := true;
                        recordbook_item := subjects_list_old(iterator);
                        EXIT;
                    END IF;
                END LOOP;

                subjects_list_new.extend;
                IF
                    subject_contains = true
                THEN
                    subjects_list_new(subjects_list_new.last) := recordbook_item;
                ELSE
                    subjects_list_new(subjects_list_new.last) := type_student_subject(subject_item.subject_name,subject_item.subject_reporting_form,NULL
);
                END IF;

            END LOOP;

            UPDATE recordbooks
                SET
                    student_subjects = subjects_list_new
            WHERE
                student_id = s_id;

            UPDATE students
                SET
                    students.student_group = s_group
            WHERE
                student_id = s_id;

        END;
    END movestudent;

    PROCEDURE setgrants (
        standard_grant NUMBER,
        upper_grant NUMBER
    )
        AS
    BEGIN
        DECLARE
            CURSOR students_recordbooks IS SELECT
                *
                                           FROM
                recordbooks;

            best_grades_count   NUMBER := 0;
            good_grades_count   NUMBER := 0;
            bad_grades_count    NUMBER := 0;
            student_grades      type_subjects;
            iterator            NUMBER;
            grade               CHAR;
            s_grant             NUMBER;
        BEGIN
            FOR student_recordbook IN students_recordbooks LOOP
                student_grades := student_recordbook.student_subjects;
                bad_grades_count := 0;
                good_grades_count := 0;
                best_grades_count := 0;
                FOR iterator IN 1..student_grades.last LOOP
                    grade := student_grades(iterator).subject_grade;
                    IF
                        grade IS NULL OR grade = 'N'
                    THEN
                        bad_grades_count := bad_grades_count + 1;
                    ELSIF grade = 'Y' OR to_number(grade) < 5 THEN
                        good_grades_count := good_grades_count + 1;
                        best_grades_count := best_grades_count + 1;
                    ELSE
                        best_grades_count := best_grades_count + 1;
                    END IF;

                END LOOP;

                IF
                    bad_grades_count > 0
                THEN
                    s_grant := 0;
                ELSIF best_grades_count = student_grades.last THEN
                    s_grant := upper_grant;
                ELSIF good_grades_count = student_grades.last THEN
                    s_grant := standard_grant;
                END IF;

                UPDATE students
                    SET
                        students.student_grant = s_grant
                WHERE
                    students.student_id = student_recordbook.student_id;

                dbms_output.put_line(student_recordbook.student_id
                || ' '
                || bad_grades_count
                || ' '
                || good_grades_count
                || ' '
                || best_grades_count
                || ' '
                || s_grant);

            END LOOP;

        END;
    END setgrants;

    PROCEDURE getaveragegrants
        AS
    BEGIN
        DECLARE
            TYPE cur IS REF CURSOR;
            students_list   cur;
            CURSOR s_groups IS SELECT DISTINCT
                students.student_group
                               FROM
                students;

            stud            NUMBER := 0;
            avg_grant       NUMBER := 0;
        BEGIN
            FOR stud_group IN s_groups LOOP
                dbms_output.put_line('Для группы '
                || stud_group.student_group
                || ':');
                SELECT
                    COUNT(*)
                INTO
                    stud
                FROM
                    students
                WHERE
                    students.student_group = stud_group.student_group;

                dbms_output.put_line('Всего студентов в группе: '
                || stud);
                SELECT
                    COUNT(*)
                INTO
                    stud
                FROM
                    students
                WHERE
                    students.student_group = stud_group.student_group
                    AND   students.student_grant > 0;

                dbms_output.put_line('Из них получают стипендию: '
                || stud);
                SELECT
                    AVG(students.student_grant)
                INTO
                    avg_grant
                FROM
                    students
                WHERE
                    students.student_group = stud_group.student_group;

                dbms_output.put_line('Средняя стипендия по группе: '
                || avg_grant);
                SELECT
                    AVG(students.student_grant)
                INTO
                    avg_grant
                FROM
                    students
                WHERE
                    students.student_group = stud_group.student_group
                    AND   students.student_grant > 0;

                dbms_output.put_line('Средняя стипендия по студентам, получающим стипендию: '
                || avg_grant);
                dbms_output.put_line('*******************');
            END LOOP;

            dbms_output.put_line('Для университета:');
            dbms_output.put_line('Всего студентов в университете: '
            || stud);
            SELECT
                COUNT(*)
            INTO
                stud
            FROM
                students
            WHERE
                students.student_grant > 0;

            dbms_output.put_line('Из них получают стипендию: '
            || stud);
            SELECT
                AVG(students.student_grant)
            INTO
                avg_grant
            FROM
                students;

            dbms_output.put_line('Средняя стипендия по университету: '
            || avg_grant);
            SELECT
                AVG(students.student_grant)
            INTO
                avg_grant
            FROM
                students
            WHERE
                students.student_grant > 0;

            dbms_output.put_line('Средняя стипендия по студентам, получающим стипендию: '
            || avg_grant);
        END;
    END getaveragegrants;

    PROCEDURE getteachersgrades
        AS
    BEGIN
        DECLARE
        -- курсор для имен преподавателей
            CURSOR teachers_cursor IS SELECT
                subjects.subject_teacher_name
                                      FROM
                subjects
            GROUP BY
                subjects.subject_teacher_name;
                
                -- курсор для предметов преподавателя по имени

            CURSOR teacher_subjects_cursor (
                teacher_name VARCHAR2
            ) IS SELECT
                *
                 FROM
                subjects
                 WHERE
                subjects.subject_teacher_name = teacher_name;

            CURSOR group_cursor (
                s_group VARCHAR2
            ) IS SELECT
                student_id,
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
                ) s_groups
                 WHERE
                s_groups.student_group = s_group;

            miss_count           NUMBER := 0;
            not_credited_count   NUMBER := 0;
            credited_count       NUMBER := 0;
            count_2              NUMBER := 0;
            count_3              NUMBER := 0;
            count_4              NUMBER := 0;
            count_5              NUMBER := 0;
            t_subject            group_cursor%rowtype;
            subjects_list        type_subjects;
            teacher_subjects     teacher_subjects_cursor%rowtype;
            iterator             NUMBER;
            grade                CHAR;
        BEGIN
        -- Цикл по именам преподавателей        
            FOR teacher IN teachers_cursor LOOP
                miss_count := 0;
                not_credited_count := 0;
                credited_count := 0;
                count_2 := 0;
                count_3 := 0;
                count_4 := 0;
                count_5 := 0;
                -- цикл по предметам конкретного преподавателя
                OPEN teacher_subjects_cursor(teacher.subject_teacher_name);
                LOOP
                    FETCH teacher_subjects_cursor INTO teacher_subjects;
                    EXIT WHEN teacher_subjects_cursor%notfound;
                    
                -- открываем курсор, в котором выборка из студентов группы с данным предметом и формой отчетности
                    OPEN group_cursor(teacher_subjects.subject_group);
                    LOOP
                        FETCH group_cursor INTO t_subject;
                        EXIT WHEN group_cursor%notfound;
                        subjects_list := t_subject.student_subjects;
                        FOR iterator IN 1..subjects_list.last LOOP
                            IF
                                subjects_list(iterator).subject_name = teacher_subjects.subject_name
                            THEN
                                grade := subjects_list(iterator).subject_grade;
                                IF
                                    grade IS NULL
                                THEN
                                    miss_count := miss_count + 1;
                                ELSIF grade = 'N' THEN
                                    not_credited_count := not_credited_count + 1;
                                ELSIF grade = 'Y' THEN
                                    credited_count := credited_count + 1;
                                ELSIF grade = '2' THEN
                                    count_2 := count_2 + 1;
                                ELSIF grade = '3' THEN
                                    count_3 := count_3 + 1;
                                ELSIF grade = '4' THEN
                                    count_4 := count_4 + 1;
                                ELSIF grade = '5' THEN
                                    count_5 := count_5 + 1;
                                END IF;

                            END IF;
                        END LOOP;

                    END LOOP;

                    CLOSE group_cursor;
                END LOOP;

                dbms_output.put_line('Оценки у преподавателя '
                || teacher.subject_teacher_name);
                dbms_output.put_line('Неявок: '
                || miss_count);
                dbms_output.put_line('Не зачтено: '
                || not_credited_count);
                dbms_output.put_line('Неудовлетворительно: '
                || count_2);
                dbms_output.put_line('Зачтено: '
                || credited_count);
                dbms_output.put_line('Удовлетворительно: '
                || count_3);
                dbms_output.put_line('Хорошо: '
                || count_4);
                dbms_output.put_line('Отлично: '
                || count_5);
                dbms_output.put_line('************************');
                CLOSE teacher_subjects_cursor;
            END LOOP;

        END;
    END getteachersgrades;

END session_pkg;