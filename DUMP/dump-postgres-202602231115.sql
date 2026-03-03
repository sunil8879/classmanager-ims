--
-- PostgreSQL database dump
--

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.0

-- Started on 2026-02-23 11:15:41

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 38 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO pg_database_owner;

--
-- TOC entry 4179 (class 0 OID 0)
-- Dependencies: 38
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- TOC entry 517 (class 1255 OID 21579)
-- Name: auto_sync_payment(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.auto_sync_payment() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (TG_OP = 'INSERT' AND NEW.paid_amount > 0) OR 
       (TG_OP = 'UPDATE' AND NEW.paid_amount <> OLD.paid_amount) THEN
       
       DECLARE
           new_cash DECIMAL := CASE 
               WHEN TG_OP = 'INSERT' THEN NEW.paid_amount 
               ELSE NEW.paid_amount - OLD.paid_amount 
           END;
       BEGIN
           IF new_cash > 0 THEN
               INSERT INTO payment_history (institute_id, student_id, roll_number, amount, payment_date, month_year)
               VALUES (
                   NEW.institute_id,
                   NEW.id,
                   NEW.roll_number,
                   new_cash,
                   CURRENT_DATE,
                   trim(to_char(CURRENT_DATE, 'FMMonth YYYY')) -- 'FM' removes hidden spaces!
               );
           END IF;
       END;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.auto_sync_payment() OWNER TO postgres;

--
-- TOC entry 460 (class 1255 OID 19172)
-- Name: get_my_institute(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_my_institute() RETURNS text
    LANGUAGE sql SECURITY DEFINER
    AS $$
  SELECT institute_id FROM profiles WHERE id = auth.uid();
$$;


ALTER FUNCTION public.get_my_institute() OWNER TO postgres;

--
-- TOC entry 472 (class 1255 OID 20333)
-- Name: get_my_institute_id(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_my_institute_id() RETURNS text
    LANGUAGE sql SECURITY DEFINER
    AS $$
  SELECT institute_id FROM profiles WHERE id = auth.uid();
$$;


ALTER FUNCTION public.get_my_institute_id() OWNER TO postgres;

--
-- TOC entry 425 (class 1255 OID 17595)
-- Name: get_my_role(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_my_role() RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT role FROM profiles WHERE id = auth.uid();
$$;


ALTER FUNCTION public.get_my_role() OWNER TO postgres;

--
-- TOC entry 440 (class 1255 OID 17078)
-- Name: rls_auto_enable(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rls_auto_enable() RETURNS event_trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


ALTER FUNCTION public.rls_auto_enable() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 413 (class 1259 OID 21675)
-- Name: alumni_tracker; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.alumni_tracker (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    institute_id text NOT NULL,
    roll_number text NOT NULL,
    full_name text,
    course_enrolled text,
    enrollment_month_year text,
    college_name text,
    stream text,
    company_name text,
    designation text,
    salary numeric DEFAULT 0,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.alumni_tracker OWNER TO postgres;

--
-- TOC entry 388 (class 1259 OID 17507)
-- Name: attendance; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.attendance (
    id bigint NOT NULL,
    date date DEFAULT CURRENT_DATE,
    user_id uuid,
    user_type text,
    status text,
    month_year text,
    remarks text,
    student_id bigint,
    roll_number text,
    attendance_date date,
    institute_id text,
    CONSTRAINT attendance_status_check CHECK ((status = ANY (ARRAY['Present'::text, 'Absent'::text]))),
    CONSTRAINT attendance_user_type_check CHECK ((user_type = ANY (ARRAY['Student'::text, 'Teacher'::text])))
);


ALTER TABLE public.attendance OWNER TO postgres;

--
-- TOC entry 387 (class 1259 OID 17506)
-- Name: attendance_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.attendance ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.attendance_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 405 (class 1259 OID 19041)
-- Name: batches; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.batches (
    id bigint NOT NULL,
    batch_name text,
    teacher_id text,
    teacher_name text,
    batch_time time without time zone,
    subject_name text,
    students_allotted integer DEFAULT 0,
    remarks text,
    institute_id text
);


ALTER TABLE public.batches OWNER TO postgres;

--
-- TOC entry 404 (class 1259 OID 19040)
-- Name: batches_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.batches ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.batches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 396 (class 1259 OID 17676)
-- Name: certificates; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.certificates (
    id bigint NOT NULL,
    student_id bigint,
    cert_number text NOT NULL,
    issued_date date DEFAULT CURRENT_DATE,
    created_at timestamp with time zone DEFAULT now(),
    institute_id text
);


ALTER TABLE public.certificates OWNER TO postgres;

--
-- TOC entry 395 (class 1259 OID 17675)
-- Name: certificates_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.certificates ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.certificates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 417 (class 1259 OID 23023)
-- Name: class_bookings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.class_bookings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    institute_id text NOT NULL,
    teacher_id text NOT NULL,
    student_roll text NOT NULL,
    booking_date date NOT NULL,
    time_slot text NOT NULL,
    course text,
    room text,
    floor text,
    created_at timestamp with time zone DEFAULT now(),
    status text DEFAULT 'pending'::text
);


ALTER TABLE public.class_bookings OWNER TO postgres;

--
-- TOC entry 407 (class 1259 OID 20334)
-- Name: exam; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.exam (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    institute_id text NOT NULL,
    exam_date date NOT NULL,
    roll_number text NOT NULL,
    full_name text,
    course_name text,
    total_marks numeric,
    marks_obtained numeric,
    percentage numeric,
    result text,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.exam OWNER TO postgres;

--
-- TOC entry 406 (class 1259 OID 19072)
-- Name: expenses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.expenses (
    month_year text NOT NULL,
    rent numeric DEFAULT 0,
    electricity numeric DEFAULT 0,
    maintenance numeric DEFAULT 0,
    teacher_salary numeric DEFAULT 0,
    admin_salary numeric DEFAULT 0,
    marketing numeric DEFAULT 0,
    other_exp numeric DEFAULT 0,
    other_income numeric DEFAULT 0,
    auto_fees_collected numeric DEFAULT 0,
    total_expenses numeric DEFAULT 0,
    total_income_net numeric DEFAULT 0,
    cost_income_ratio numeric DEFAULT 0,
    created_at timestamp with time zone DEFAULT now(),
    institute_id text
);


ALTER TABLE public.expenses OWNER TO postgres;

--
-- TOC entry 411 (class 1259 OID 20442)
-- Name: institute_calendar; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.institute_calendar (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    institute_id text,
    event_date date,
    event_name text,
    event_type text,
    description text,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.institute_calendar OWNER TO postgres;

--
-- TOC entry 394 (class 1259 OID 17642)
-- Name: institute_settings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.institute_settings (
    id bigint NOT NULL,
    institute_name text DEFAULT 'My Coaching Institute'::text,
    branch_name text DEFAULT 'Main Branch'::text,
    authorised_signatory text DEFAULT 'Director'::text,
    created_at timestamp with time zone DEFAULT now(),
    institute_id text
);


ALTER TABLE public.institute_settings OWNER TO postgres;

--
-- TOC entry 393 (class 1259 OID 17641)
-- Name: institute_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.institute_settings ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.institute_settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 415 (class 1259 OID 21712)
-- Name: inventory_master; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.inventory_master (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    institute_id text NOT NULL,
    item_name text NOT NULL,
    current_stock integer DEFAULT 0,
    item_price numeric(10,2) DEFAULT 0,
    vendor_type text
);


ALTER TABLE public.inventory_master OWNER TO postgres;

--
-- TOC entry 416 (class 1259 OID 21724)
-- Name: inventory_sales; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.inventory_sales (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    institute_id text NOT NULL,
    student_roll text NOT NULL,
    student_name text,
    course_name text,
    items_bought text,
    total_paid numeric(10,2) DEFAULT 0,
    remarks text,
    created_at timestamp with time zone DEFAULT now(),
    month_year text
);


ALTER TABLE public.inventory_sales OWNER TO postgres;

--
-- TOC entry 414 (class 1259 OID 21695)
-- Name: inventory_tracker; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.inventory_tracker (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    institute_id text NOT NULL,
    item_name text NOT NULL,
    current_stock_level integer DEFAULT 0,
    items_sold integer DEFAULT 0,
    item_price numeric(10,2) DEFAULT 0,
    total_income numeric(10,2) DEFAULT 0,
    balance_stock integer DEFAULT 0,
    vendor_name text,
    student_roll text,
    student_name text,
    course_name text,
    items_bought_list text,
    total_price_paid numeric(10,2) DEFAULT 0,
    remarks text,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.inventory_tracker OWNER TO postgres;

--
-- TOC entry 390 (class 1259 OID 17523)
-- Name: leads; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.leads (
    id bigint NOT NULL,
    full_name text NOT NULL,
    contact text NOT NULL,
    email text,
    interested_course text,
    date_of_visit date DEFAULT CURRENT_DATE,
    reference text,
    status text DEFAULT 'Follow up'::text,
    remarks text,
    institute_id text,
    CONSTRAINT leads_status_check CHECK ((status = ANY (ARRAY['Follow up'::text, 'Converted'::text, 'Not interested'::text])))
);


ALTER TABLE public.leads OWNER TO postgres;

--
-- TOC entry 389 (class 1259 OID 17522)
-- Name: leads_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.leads ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.leads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 420 (class 1259 OID 24282)
-- Name: list; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.list (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    institute_id text NOT NULL,
    date_today date,
    roll_number text NOT NULL,
    student_name text,
    teacher_id text,
    teacher_name text,
    course_name text,
    batch_name text,
    remarks text
);


ALTER TABLE public.list OWNER TO postgres;

--
-- TOC entry 410 (class 1259 OID 20419)
-- Name: messages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    institute_id text NOT NULL,
    sender_name text,
    sender_role text,
    message_type text,
    target_subject text,
    content text,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.messages OWNER TO postgres;

--
-- TOC entry 400 (class 1259 OID 18869)
-- Name: payment_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.payment_history (
    id bigint NOT NULL,
    student_id bigint,
    roll_number text,
    amount numeric,
    payment_date date,
    month_year text,
    created_at timestamp with time zone DEFAULT now(),
    institute_id text,
    full_name text,
    date_of_joining date,
    course_name text,
    total_fees numeric,
    previously_paid numeric,
    pending_fees numeric,
    due_dates text,
    status text DEFAULT 'Active'::text
);


ALTER TABLE public.payment_history OWNER TO postgres;

--
-- TOC entry 399 (class 1259 OID 18868)
-- Name: payment_history_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.payment_history ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.payment_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 398 (class 1259 OID 17694)
-- Name: performance_tracking; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.performance_tracking (
    id bigint NOT NULL,
    student_id bigint,
    total_marks_secured numeric DEFAULT 0,
    total_exams integer DEFAULT 0,
    teacher_name text,
    updated_at timestamp with time zone DEFAULT now(),
    institute_id text,
    roll_number text
);


ALTER TABLE public.performance_tracking OWNER TO postgres;

--
-- TOC entry 397 (class 1259 OID 17693)
-- Name: performance_tracking_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.performance_tracking ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.performance_tracking_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 392 (class 1259 OID 17625)
-- Name: profiles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    full_name text,
    email text,
    role text,
    mobile_number text,
    address text,
    created_at timestamp with time zone DEFAULT now(),
    state text,
    institute_id text
);


ALTER TABLE public.profiles OWNER TO postgres;

--
-- TOC entry 419 (class 1259 OID 24252)
-- Name: ptm_schedule; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ptm_schedule (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    institute_id text NOT NULL,
    month_year text NOT NULL,
    ptm_date date NOT NULL,
    start_time time without time zone NOT NULL,
    end_time time without time zone NOT NULL,
    slot_duration integer NOT NULL,
    status text DEFAULT 'Open'::text,
    roll_number text NOT NULL,
    student_name text,
    course_name text,
    teacher_id text NOT NULL,
    teacher_name text,
    slot_time time without time zone NOT NULL,
    teacher_mobile text,
    mother_mobile text,
    father_mobile text,
    remarks text,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.ptm_schedule OWNER TO postgres;

--
-- TOC entry 418 (class 1259 OID 24210)
-- Name: scholarships; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.scholarships (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    institute_id text NOT NULL,
    roll_number text NOT NULL,
    student_name text,
    course_name text,
    total_course_fee numeric DEFAULT 0,
    scholarship_name text,
    applied_on date,
    docs_required text,
    status text DEFAULT 'Pending'::text,
    scholarship_pct numeric DEFAULT 0,
    scholarship_amount numeric DEFAULT 0,
    final_fees numeric DEFAULT 0,
    valid_from date,
    valid_to date,
    remarks text,
    document_url text,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.scholarships OWNER TO postgres;

--
-- TOC entry 409 (class 1259 OID 20383)
-- Name: student_allocations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.student_allocations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    institute_id text NOT NULL,
    teacher_id text NOT NULL,
    teacher_name text NOT NULL,
    roll_number text NOT NULL,
    student_name text NOT NULL,
    subject text,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.student_allocations OWNER TO postgres;

--
-- TOC entry 391 (class 1259 OID 17567)
-- Name: student_details; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.student_details (
    student_id bigint NOT NULL,
    user_id uuid,
    age integer,
    gender text,
    residence text,
    roll_number text,
    course_duration text,
    course_end_date date,
    fee_due_date date,
    remarks text,
    created_at timestamp with time zone DEFAULT now(),
    institute_id text,
    CONSTRAINT student_details_gender_check CHECK ((gender = ANY (ARRAY['Male'::text, 'Female'::text, 'Other'::text])))
);


ALTER TABLE public.student_details OWNER TO postgres;

--
-- TOC entry 403 (class 1259 OID 19027)
-- Name: students; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.students (
    id bigint NOT NULL,
    admission_date date,
    full_name text,
    mobile text,
    father_mobile text,
    mother_mobile text,
    standard text,
    batch_time time without time zone,
    course text,
    total_fees numeric DEFAULT 0,
    paid_amount numeric DEFAULT 0,
    pending_amount numeric DEFAULT 0,
    roll_number text,
    status text DEFAULT 'Active'::text,
    user_id uuid,
    institute_id text,
    due_dates text,
    course_end_date date
);


ALTER TABLE public.students OWNER TO postgres;

--
-- TOC entry 402 (class 1259 OID 19026)
-- Name: students_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.students ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.students_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 401 (class 1259 OID 19019)
-- Name: teacher_details; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.teacher_details (
    id text NOT NULL,
    teacher_name text,
    age integer,
    gender text,
    joining_date date,
    qualification text,
    subject_taught text,
    salary_offered numeric,
    institute_id text,
    mobile text,
    rating numeric DEFAULT 5,
    full_address text,
    email text DEFAULT 'pending@update-me.com'::text NOT NULL,
    experience text,
    status character varying(20) DEFAULT 'active'::character varying,
    availability character varying(3) DEFAULT 'no'::character varying,
    time_of_slot text DEFAULT ''::text
);


ALTER TABLE public.teacher_details OWNER TO postgres;

--
-- TOC entry 412 (class 1259 OID 21640)
-- Name: teacher_payments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.teacher_payments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    institute_id text NOT NULL,
    teacher_id text NOT NULL,
    full_name text NOT NULL,
    subject_taught text,
    joining_date date,
    payment_date date DEFAULT CURRENT_DATE,
    month_year text NOT NULL,
    amount_paid numeric(10,2) DEFAULT 0,
    pending_amount numeric(10,2) DEFAULT 0,
    created_at timestamp with time zone DEFAULT now(),
    age integer,
    qualification text,
    whatsapp text
);


ALTER TABLE public.teacher_payments OWNER TO postgres;

--
-- TOC entry 408 (class 1259 OID 20343)
-- Name: teachers_attendance; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.teachers_attendance (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    institute_id text NOT NULL,
    month_year text NOT NULL,
    teacher_id text NOT NULL,
    full_name text,
    attendance_date date NOT NULL,
    status text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.teachers_attendance OWNER TO postgres;

--
-- TOC entry 4166 (class 0 OID 21675)
-- Dependencies: 413
-- Data for Name: alumni_tracker; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.alumni_tracker (id, institute_id, roll_number, full_name, course_enrolled, enrollment_month_year, college_name, stream, company_name, designation, salary, created_at) FROM stdin;
f5bad07c-c4a8-4847-b867-60baaa377ffc	CM-3605	IMS-2026-1415	yogesh d	Accounts	January 2026	IIT-POWAI, Mumbai	Engineering	NA	NA	0	2026-02-19 17:59:53.650575+00
\.


--
-- TOC entry 4141 (class 0 OID 17507)
-- Dependencies: 388
-- Data for Name: attendance; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.attendance (id, date, user_id, user_type, status, month_year, remarks, student_id, roll_number, attendance_date, institute_id) FROM stdin;
1	2026-02-17	9ccae1e5-29ee-46fb-8f78-7128de725323	\N	Present	2026-02	\N	\N	\N	\N	\N
2	2026-02-17	9ccae1e5-29ee-46fb-8f78-7128de725323	\N	Absent	2026-02	\N	\N	\N	\N	\N
3	2026-02-17	9ccae1e5-29ee-46fb-8f78-7128de725323	\N	Present	February 2026	\N	3	IMS-2026-1871	2026-02-17	\N
4	2026-02-17	\N	\N	Present	February 2026	\N	1	IMS-2026-4336	2026-02-17	\N
5	2026-02-17	dc4ca84b-e9e0-497e-bf9a-f40166ce7428	\N	Absent	February 2026	\N	1	IMS-2026-4336	2026-02-17	\N
6	2026-02-17	dc4ca84b-e9e0-497e-bf9a-f40166ce7428	\N	Absent	February 2026	\N	1	IMS-2026-4336	2026-02-17	\N
7	2026-02-18	8acf4dec-4f31-4a9b-8bee-27357658e588	\N	Present	February 2026	\N	9	IMS-2026-3438	2026-02-18	CM-3605
8	2026-02-19	8acf4dec-4f31-4a9b-8bee-27357658e588	\N	Present	February 2026	\N	24	IMS-2026-5911	2026-02-20	CM-3605
9	2026-02-19	8acf4dec-4f31-4a9b-8bee-27357658e588	\N	Absent	February 2026	\N	25	IMS-2026-9192	2026-02-20	CM-3605
10	2026-02-19	8acf4dec-4f31-4a9b-8bee-27357658e588	\N	Present	February 2026	\N	26	IMS-2026-8115	2026-02-20	CM-3605
11	2026-02-20	8acf4dec-4f31-4a9b-8bee-27357658e588	\N	Absent	February 2026	\N	27	IMS-2026-1732	2026-02-20	CM-3605
\.


--
-- TOC entry 4158 (class 0 OID 19041)
-- Dependencies: 405
-- Data for Name: batches; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.batches (id, batch_name, teacher_id, teacher_name, batch_time, subject_name, students_allotted, remarks, institute_id) FROM stdin;
1	spoken english batch	TCH 8638	sunil v	11:30:00	english	15	only 5 are present	\N
3	maths master	TCH-3784	seema joshi	14:40:00	geometry	20		CM-3605
\.


--
-- TOC entry 4149 (class 0 OID 17676)
-- Dependencies: 396
-- Data for Name: certificates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.certificates (id, student_id, cert_number, issued_date, created_at, institute_id) FROM stdin;
1	3	IMS/CERT/2026/8209	2026-02-16	2026-02-16 23:59:11.150089+00	\N
2	1	IMS/CERT/2026/7498	2026-02-17	2026-02-17 14:52:08.16379+00	\N
\.


--
-- TOC entry 4170 (class 0 OID 23023)
-- Dependencies: 417
-- Data for Name: class_bookings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.class_bookings (id, institute_id, teacher_id, student_roll, booking_date, time_slot, course, room, floor, created_at, status) FROM stdin;
f3b72325-c6f2-4bcd-90f7-881111bd1708	CM-3605	TCH-3060	IMS-2026-9192	2026-02-21	10:00 AM to 11:00 AM	geometry	5	1st	2026-02-20 20:58:17.870019+00	pending
7efdf64e-d22e-4281-a17a-7ad9b72327ef	CM-3605	TCH-3060	IMS-2026-9192	2026-02-19	10:00 AM to 11:00 AM	geometry	1	Ground	2026-02-20 21:05:42.190254+00	pending
78bfeade-0603-49b5-a3ee-2fef24d55352	CM-3605	TCH-3060	IMS-2026-9192	2026-02-22	10:00 AM to 11:00 AM	geometry	\N	\N	2026-02-20 21:21:25.024357+00	pending
12bdf174-8da0-4e94-8bac-853c2dd5dbeb	CM-3605	TCH-3060	IMS-2026-9192	2026-02-28	03:00 PM to 04:00 PM	geometry	\N	\N	2026-02-20 21:43:04.884912+00	pending
ec0c26de-3466-48ae-9397-81ce7daa8f76	CM-3605	TCH-3060	IMS-2026-9192	2026-02-27	09:00 AM to 10:00 AM	geometry	\N	\N	2026-02-20 22:14:28.827187+00	pending
b1283b7d-a839-4773-9699-6a432ac740d6	CM-3605	TCH-3060	IMS-2026-9192	2026-02-26	09:00 AM to 10:00 AM	geometry	\N	\N	2026-02-20 22:28:08.153632+00	pending
8d44e991-7b35-48d8-bb23-9f21b3499dbb	CM-3605	TCH-3060	IMS-2026-9192	2026-02-25	09:00 AM to 10:00 AM	geometry	\N	\N	2026-02-20 22:33:41.954332+00	pending
b4c40f6d-c1dd-404e-b05d-5bbf84532ed2	CM-3605	TCH-3060	IMS-2026-9192	2026-02-21	11:00 AM to 12:00 PM	geometry	\N	\N	2026-02-20 22:34:37.865822+00	pending
714c5b85-9bac-4d77-abc8-af117a91037c	CM-3605	TCH-3060	IMS-2026-9192	2026-02-26	11:00 AM to 12:00 PM	geometry	\N	\N	2026-02-20 23:10:19.167271+00	pending
734034a5-a371-495f-b507-144982a6d162	CM-3605	TCH-3060	IMS-2026-9192	2026-02-23	10:00 AM to 11:00 AM	geometry	\N	\N	2026-02-20 23:29:32.857028+00	pending
c09a8538-d56e-405b-b7ef-a307b8a06fe2	CM-3605	TCH-3060	IMS-2026-9192	2026-02-24	10:00 AM to 11:00 AM	geometry	\N	\N	2026-02-20 23:33:18.770668+00	pending
0ca86472-d2aa-4308-b2e2-5c28f2bd8d94	CM-3605	TCH-3060	IMS-2026-9192	2026-02-28	11:00 AM to 12:00 PM	geometry	\N	\N	2026-02-21 01:07:20.900677+00	pending
8b08321b-af07-4250-972f-d58a86e3d970	CM-3605	TCH-3060	IMS-2026-9192	2026-02-22	09:00 AM to 10:00 AM	geometry	\N	\N	2026-02-21 07:32:43.44378+00	pending
62f78999-e503-4ab3-a3fd-cac31c392cec	CM-3605	TCH-7224	IMS-2026-9192	2026-02-21	09:00 AM to 10:00 AM	geometry	\N	\N	2026-02-21 09:45:50.225779+00	pending
53c81813-9420-4306-9db4-0371e970d50a	CM-3605	TCH-2342	IMS-2026-9192	2026-02-21	02:00 PM to 03:00 PM	geometry	\N	\N	2026-02-21 14:50:53.638744+00	pending
4c84ea25-dc1c-40e0-a79a-94959666b2b6	CM-3605	TCH-2342	IMS-2026-9192	2026-02-21	09:00 AM to 10:00 AM	geometry	\N	\N	2026-02-21 14:50:59.606129+00	pending
e1ff5943-30ac-4e9e-81dd-891151892473	CM-3605	TCH-2342	IMS-2026-9192	2026-02-21	11:00 AM to 12:00 PM	geometry	\N	\N	2026-02-21 15:24:20.208984+00	pending
c0654337-3ba4-4c5b-a91f-d53a60dafed7	CM-3605	TCH-8139	IMS-2026-9192	2026-02-21	09:00 AM to 10:00 AM	geometry	\N	\N	2026-02-21 15:38:00.474578+00	pending
cace2708-d14b-4ca5-9fae-21bff32502f4	CM-3605	TCH-8139	IMS-2026-9192	2026-02-21	10:00 AM to 11:00 AM	geometry	\N	\N	2026-02-21 15:38:14.528795+00	pending
fe516981-6932-45f9-bc95-bc05b5f29c33	CM-3605	TCH-8139	IMS-2026-9192	2026-02-21	12:00 PM to 01:00 PM	geometry	\N	\N	2026-02-21 15:38:36.313997+00	pending
eddbce5c-3c62-4b91-ba24-8222fc88c392	CM-3605	TCH-7409	IMS-2026-5171	2026-02-21	08:00 PM to 09:00 PM	maths	\N	\N	2026-02-21 15:59:40.540769+00	pending
2ea44aec-d21e-4180-a8bf-ebe7af77cce7	CM-3605	TCH-2342	IMS-2026-9192	2026-02-23	09:00 AM to 10:00 AM	geometry	\N	\N	2026-02-22 14:46:53.949335+00	pending
\.


--
-- TOC entry 4160 (class 0 OID 20334)
-- Dependencies: 407
-- Data for Name: exam; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.exam (id, institute_id, exam_date, roll_number, full_name, course_name, total_marks, marks_obtained, percentage, result, created_at) FROM stdin;
18a85831-6cba-4b94-8df4-036f12de65df	CM-3605	2026-02-18	IMS-2026-3438	khushboo rathod	mathematics	100	74	74	B Grade	2026-02-18 12:07:48.855975+00
6d18b337-1633-4493-b30f-c0fedf7b3dbc	CM-3605	2026-02-20	IMS-2026-5911	Amrut W	algebra	100	79	79	A Grade	2026-02-19 22:49:03.56346+00
e2c116f3-2d26-4c74-87a5-1720f751977a	CM-3605	2026-02-20	IMS-2026-9192	Ashish M	Geometry	100	79	79	A Grade	2026-02-19 22:49:22.657273+00
a54cfc34-77c7-47ac-a9c9-5548f0359d50	CM-3605	2026-02-20	IMS-2026-8115	Amogh S	Physics	100	87	87	Distinction	2026-02-19 22:50:33.31229+00
\.


--
-- TOC entry 4159 (class 0 OID 19072)
-- Dependencies: 406
-- Data for Name: expenses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.expenses (month_year, rent, electricity, maintenance, teacher_salary, admin_salary, marketing, other_exp, other_income, auto_fees_collected, total_expenses, total_income_net, cost_income_ratio, created_at, institute_id) FROM stdin;
2026-02	1000	2000	0	4000	5000	0	7000	2700	21000	19000	2000	90.5	2026-02-17 14:13:08.465778+00	CM-3605
Feb 2026	100	200	300	400	500	600	700	0	0	2800	18450	12.1	2026-02-19 19:54:08.730953+00	CM-3605
\.


--
-- TOC entry 4164 (class 0 OID 20442)
-- Dependencies: 411
-- Data for Name: institute_calendar; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.institute_calendar (id, institute_id, event_date, event_name, event_type, description, created_at) FROM stdin;
cb58d7d9-b151-4eb5-9a6c-3f13d77a6a22		2026-02-22	Diwali celebration holiday for 3 days	Holiday	Holidays	2026-02-22 17:49:59.69024+00
\.


--
-- TOC entry 4147 (class 0 OID 17642)
-- Dependencies: 394
-- Data for Name: institute_settings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.institute_settings (id, institute_name, branch_name, authorised_signatory, created_at, institute_id) FROM stdin;
1	CLASS MANAGER IMS	Mumbai West	Admin Office	2026-02-16 23:15:06.443688+00	\N
\.


--
-- TOC entry 4168 (class 0 OID 21712)
-- Dependencies: 415
-- Data for Name: inventory_master; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.inventory_master (id, institute_id, item_name, current_stock, item_price, vendor_type) FROM stdin;
661ab048-bedc-47c9-b4d7-dedd6d49b9b6	CM-3605	Geometry	7	100.00	\N
d0f9fa43-c47a-4b0a-80d9-c5536f19fdc4	CM-3605	Physics	92	100.00	\N
1a99e1f8-4690-4e9b-afcf-15b2e7998778	CM-3605	Geography	37	100.00	\N
499c9405-4fc4-47b4-bc7d-17e60409ae0f	CM-3605	Spoken English	73	250.00	\N
541f23e1-5432-43ec-945b-75f0d71c116f	CM-3605	Chemistry	94	100.00	\N
357603c1-1b5a-46c7-801e-208dc4b5ae19	CM-3605	Biology	94	100.00	\N
e29851fc-065b-438e-93d3-315fc61a5066	CM-3605	History	29	100.00	\N
0accea25-2e24-4c9d-a130-b292f97dccf1	CM-3605	English Grammar	74	250.00	\N
8f116df3-8b5b-4da8-ac23-2cf9b84c18f0	CM-3605	Economics	18	100.00	\N
df78c542-895f-4b07-9051-7b1fffde6de7	CM-3605	Accounting	19	100.00	\N
4537f8c6-1eb8-4e02-8ccb-2641e6d292da	CM-3605	Drawing	19	100.00	\N
df6abb29-6d23-4b65-8cc5-3178ec80fbcd	CM-3605	JEE	98	500.00	\N
dde32df5-cb39-47e4-9537-a3261df4b396	CM-3605	NEET	98	500.00	\N
53e2832b-4ed4-4540-a0ef-aae5df8d03e6	CM-3605	French	15	100.00	\N
ef4497a9-a040-4762-9132-6bddf6e72e9d	CM-3605	Spanish	15	100.00	\N
a2fd6c87-39a4-443c-8fa6-76396b95fff8	CM-3605	German	15	100.00	\N
b02741b6-3990-4326-8062-9b53e3e3069f	CM-3605	Uniforms	200	100.00	\N
c007093d-b55a-42a6-bf5e-d242e6babfa2	CM-3605	Bags	50	350.00	\N
d75006cd-6fec-46ae-bd7c-d02071dac187	CM-3605	Calendars	50	75.00	\N
2076043f-655a-4875-8e51-70c3d076c469	CM-3605	Others	0	0.00	\N
8d25acf8-a93d-4047-abac-af3d7e372517	CM-3605	Algebra	12	100.00	\N
\.


--
-- TOC entry 4169 (class 0 OID 21724)
-- Dependencies: 416
-- Data for Name: inventory_sales; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.inventory_sales (id, institute_id, student_roll, student_name, course_name, items_bought, total_paid, remarks, created_at, month_year) FROM stdin;
8295a0ec-6e19-4e36-8593-21a5ca7ec439	CM-3605	IMS-2026-4728	manisha patel	drawing	Geography (1), Economics (1), Accounting (1), Drawing (1)	400.00	sold 4 important books	2026-02-19 21:36:41.881777+00	February 2026
a4d16ee8-9554-43e5-abe1-494d4fd4179c	CM-3605	IMS-2026-4728	manisha patel	drawing	JEE (1), NEET (1)	1000.00	2 useful books	2026-02-19 22:15:40.795872+00	February 2026
0cdefef7-6bb2-49cf-aaff-262bc2865258	CM-3605	IMS-2026-9192	Ashish M	Geometry	Algebra (1), Geometry (1), Physics (1), Geography (1), Spoken English (1)	650.00		2026-02-20 07:32:03.381769+00	February 2026
\.


--
-- TOC entry 4167 (class 0 OID 21695)
-- Dependencies: 414
-- Data for Name: inventory_tracker; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.inventory_tracker (id, institute_id, item_name, current_stock_level, items_sold, item_price, total_income, balance_stock, vendor_name, student_roll, student_name, course_name, items_bought_list, total_price_paid, remarks, created_at) FROM stdin;
\.


--
-- TOC entry 4143 (class 0 OID 17523)
-- Dependencies: 390
-- Data for Name: leads; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.leads (id, full_name, contact, email, interested_course, date_of_visit, reference, status, remarks, institute_id) FROM stdin;
1	siddharth L	9999999999	\N	\N	2026-02-17	\N	Follow up	\N	\N
2	kapil patil	8888844444	\N	\N	2026-02-17	\N	Follow up	\N	\N
3	mukesh bhati	1111100000	mukesh@rediffmail.com	german	2026-02-17	google	Follow up	will call us after 2 days	\N
\.


--
-- TOC entry 4173 (class 0 OID 24282)
-- Dependencies: 420
-- Data for Name: list; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.list (id, created_at, institute_id, date_today, roll_number, student_name, teacher_id, teacher_name, course_name, batch_name, remarks) FROM stdin;
c5952335-0850-407d-be0d-ef3662fc3243	2026-02-22 09:46:40.104284+00	CM-3605	2026-02-22	IMS-2026-9192	Ashish M	TCH-3784	seema joshi	geometry	maths master	
\.


--
-- TOC entry 4163 (class 0 OID 20419)
-- Dependencies: 410
-- Data for Name: messages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.messages (id, institute_id, sender_name, sender_role, message_type, target_subject, content, created_at) FROM stdin;
8ba7aa28-a3d6-4780-8b6a-f40aca95f185	CM-3605	riya vasarkar		TeacherToStudent	All	hello, tomorrow is a holiday	2026-02-18 17:49:57.529361+00
a0d49e70-3a3d-4b54-b28a-becda32beb4e	CM-3605	riya vasarkar		General	All	i m not coming tomorrow	2026-02-18 17:50:48.086525+00
6ce660fc-989b-4620-b63d-94e8e969d21a	CM-3605	riya vasarkar		General	All	hello all. tomorrow i will come half day	2026-02-18 18:01:11.742669+00
cd661280-fd7d-43a7-a9cd-287c5ec7dca1	CM-3605	riya vasarkar	Owner	Teacher	General	hi, tomorrow there is ameeting for all teachers	2026-02-18 19:24:15.137+00
47a08e3a-56f1-4386-ad26-b4e6b7e295c2	CM-3605	riya vasarkar	Owner	Teacher	Mathematics	tomorrow maths test would be there	2026-02-18 19:48:59.670807+00
\.


--
-- TOC entry 4153 (class 0 OID 18869)
-- Dependencies: 400
-- Data for Name: payment_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.payment_history (id, student_id, roll_number, amount, payment_date, month_year, created_at, institute_id, full_name, date_of_joining, course_name, total_fees, previously_paid, pending_fees, due_dates, status) FROM stdin;
19	21	IMS-2026-5171	11000	2026-02-19	February 2026	2026-02-19 17:10:12.595037+00	CM-3605	\N	\N	\N	\N	\N	\N	\N	Active
20	22	IMS-2026-4728	10000	2026-02-19	February 2026	2026-02-19 17:47:58.034828+00	CM-3605	\N	\N	\N	\N	\N	\N	\N	Active
21	23	IMS-2026-1415	10000	2026-01-01	January 2026	2026-02-19 17:51:33.434194+00	CM-3605	\N	\N	\N	\N	\N	\N	\N	Active
22	24	IMS-2026-5911	7000	2026-02-20	February 2026	2026-02-19 22:42:19.210652+00	CM-3605	\N	\N	\N	\N	\N	\N	\N	Active
23	25	IMS-2026-9192	5000	2026-02-20	February 2026	2026-02-19 22:43:50.407746+00	CM-3605	\N	\N	\N	\N	\N	\N	\N	Active
24	26	IMS-2026-8115	4000	2026-02-20	February 2026	2026-02-19 22:45:12.851612+00	CM-3605	\N	\N	\N	\N	\N	\N	\N	Active
25	27	IMS-2026-1732	5000	2026-02-20	February 2026	2026-02-20 00:16:35.521682+00	CM-3605	\N	\N	\N	\N	\N	\N	\N	Active
26	28	IMS-2026-7632	20000	2026-02-20	February 2026	2026-02-20 10:06:29.460895+00	CM-3605	\N	\N	\N	\N	\N	\N	\N	Active
27	25	IMS-2026-9192	2000	2026-02-20	February 2026	2026-02-20 12:10:58.291227+00	CM-3605	\N	\N	\N	\N	\N	\N	\N	Active
28	30	IMS-2026-7768	15000	2026-02-22	February 2026	2026-02-22 12:04:29.469357+00	CM-2618	\N	\N	\N	\N	\N	\N	\N	Active
29	33	IMS-2026-6661	20000	2026-02-22	February 2026	2026-02-22 12:20:31.004954+00	CM-3605	\N	\N	\N	\N	\N	\N	\N	Active
\.


--
-- TOC entry 4151 (class 0 OID 17694)
-- Dependencies: 398
-- Data for Name: performance_tracking; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.performance_tracking (id, student_id, total_marks_secured, total_exams, teacher_name, updated_at, institute_id, roll_number) FROM stdin;
1	3	276	3	sunil v	2026-02-17 00:31:47.873+00	\N	\N
2	1	600	8	sunil v	2026-02-17 14:53:15.28+00	\N	\N
\.


--
-- TOC entry 4145 (class 0 OID 17625)
-- Dependencies: 392
-- Data for Name: profiles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.profiles (id, full_name, email, role, mobile_number, address, created_at, state, institute_id) FROM stdin;
dc4ca84b-e9e0-497e-bf9a-f40166ce7428	bhavesh pandya	bhavesh@gmail.com	Teacher	0000000000	\N	2026-02-17 09:51:28.393031+00	\N	\N
95a2df08-0c03-4436-903d-65efd507469c	samit shah	samitshah@rediffmail.com	Owner	8888888888	\N	2026-02-17 10:13:38.835047+00	Maharashtra	\N
9ccae1e5-29ee-46fb-8f78-7128de725323	sunil vasarkar	sunilvasarkar1975@gmail.com	Owner	8879267011	\N	2026-02-16 23:05:49.33458+00	\N	CM-1001
8acf4dec-4f31-4a9b-8bee-27357658e588	riya vasarkar	vasarkarriya@rediffmail.com	Owner	9136516298	\N	2026-02-18 07:22:08.459136+00	Maharashtra	CM-3605
9b3d6a6f-a21b-4d34-ab7a-4c89ab48f022	alpesh	alpesh1@gmail.com	Teacher	9797979797	\N	2026-02-22 11:09:15.559352+00	Gujarat	CM-4663
6d702daf-9708-49fb-9776-333537a625e1	pinky	pinky1@gmail.com	Student	7676767676	\N	2026-02-22 11:11:45.274885+00	Maharashtra	CM-6093
e7e7c00e-7c21-45ec-8115-098b297e3ae5	sunil	sunil1@gmail.com	Owner	7575757575	\N	2026-02-22 11:23:17.190265+00	Maharashtra	CM-2133
1fa1fe41-4d69-4073-bea8-cb1eb195bb33	Bhavesh patel	bhavesh7@gmail.com	Teacher	8686868686	\N	2026-02-22 11:56:44.384282+00	Maharashtra	CM-3605
3e42e9f9-cbd6-4712-9dd5-68fbd59c6604	ashwin patel	ashwin7@gmail.com	Owner	7373737373	\N	2026-02-22 11:58:45.757224+00	Maharashtra	CM-2618
c259c8ca-3b25-44f1-8316-8a71f9d3826e	sonu mehta	sonu7@gmail.com	Student	7171717171	\N	2026-02-22 12:09:39.42274+00	Maharashtra	CM-3605
c1b9d561-78a4-44c3-a0eb-2a30741444b7	deepak rathod	deepak7@gmail.com	Student	7272727272	\N	2026-02-22 12:13:39.516369+00	Manipur	CM-3605
\.


--
-- TOC entry 4172 (class 0 OID 24252)
-- Dependencies: 419
-- Data for Name: ptm_schedule; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ptm_schedule (id, institute_id, month_year, ptm_date, start_time, end_time, slot_duration, status, roll_number, student_name, course_name, teacher_id, teacher_name, slot_time, teacher_mobile, mother_mobile, father_mobile, remarks, created_at) FROM stdin;
ed2b1ff5-7dfb-4ded-a70a-e5dd8e8dcdd0	CM-3605	February 2026	2026-02-28	10:00:00	13:00:00	15	Open	IMS-2026-5171	pinky patel	maths	TCH-1601	Amit dalvi	10:00:00	9898989898	3333333333	2222222222		2026-02-21 20:08:42.795933+00
\.


--
-- TOC entry 4171 (class 0 OID 24210)
-- Dependencies: 418
-- Data for Name: scholarships; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.scholarships (id, institute_id, roll_number, student_name, course_name, total_course_fee, scholarship_name, applied_on, docs_required, status, scholarship_pct, scholarship_amount, final_fees, valid_from, valid_to, remarks, document_url, created_at) FROM stdin;
44e94589-3440-43da-8d19-6d778c3197cd	CM-3605	IMS-2026-5171	pinky patel	maths	25000	Talent search 2026	2026-02-21	Aadhaar card	Pending	0	0	25000	\N	\N	still pending		2026-02-21 18:35:39.62439+00
aace7772-2647-4a22-99c5-a30666d63c4a	CM-3605	IMS-2026-5911	Amrut W	algebra	10000	Talent search 2026	2026-02-21	Aadhaar card	Approved	10	1000	9000	2026-02-22	2027-02-20	still pending		2026-02-21 18:59:04.878482+00
\.


--
-- TOC entry 4162 (class 0 OID 20383)
-- Dependencies: 409
-- Data for Name: student_allocations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.student_allocations (id, institute_id, teacher_id, teacher_name, roll_number, student_name, subject, created_at) FROM stdin;
c7f62c93-9141-4c4d-9d1c-5115444a8a97	CM-3605	TCH-1709	sanjay sengupta	IMS-2026-3438	khushboo rathod	MATHEMATICS	2026-02-18 15:18:46.27925+00
f0032289-d004-4f83-907e-c75de3975dee	CM-3605	TCH-1709	sanjay sengupta	IMS-2026-3438	khushboo rathod	mathematics	2026-02-18 15:28:08.13693+00
21129582-fe76-4fea-b72f-0fe2e4563b4a	CM-3605	TCH-1601	Amit dalvi	IMS-2026-5171	pinky patel	maths	2026-02-21 20:06:47.643062+00
8f0a6772-b683-4fa2-88a6-f5873a3513f8	CM-3605	TCH-3784	seema joshi	IMS-2026-9192	Ashish M	geometry	2026-02-22 09:46:06.749615+00
\.


--
-- TOC entry 4144 (class 0 OID 17567)
-- Dependencies: 391
-- Data for Name: student_details; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.student_details (student_id, user_id, age, gender, residence, roll_number, course_duration, course_end_date, fee_due_date, remarks, created_at, institute_id) FROM stdin;
2	\N	\N	\N	\N	1000	\N	2026-03-31	\N	\N	2026-02-16 23:35:17.878548+00	\N
6	\N	\N	\N	\N	IMS-2026-7697	\N	2026-05-31	\N	\N	2026-02-17 10:56:04.838571+00	\N
1	\N	\N	\N	\N	IMS-2026-4336	\N	2026-05-31	\N	\N	2026-02-17 13:04:48.265144+00	CM-1001
7	\N	\N	\N	\N	IMS-2026-3949	\N	2026-05-31	\N	\N	2026-02-17 21:20:46.094219+00	CM-2002
8	\N	\N	\N	\N	IMS-2026-8722	\N	2026-05-31	\N	\N	2026-02-17 23:30:51.910811+00	CM-1001
21	\N	\N	\N	\N	IMS-2026-5171	\N	2026-05-31	\N	\N	2026-02-19 17:10:12.446743+00	CM-3605
22	\N	\N	\N	\N	IMS-2026-4728	\N	2026-02-28	\N	\N	2026-02-19 17:47:57.904833+00	CM-3605
23	\N	\N	\N	\N	IMS-2026-1415	\N	2026-02-01	\N	\N	2026-02-19 17:51:33.291216+00	CM-3605
24	\N	\N	\N	\N	IMS-2026-5911	\N	2027-02-20	\N	\N	2026-02-19 22:42:19.005619+00	CM-3605
26	\N	\N	\N	\N	IMS-2026-8115	\N	2027-02-20	\N	\N	2026-02-19 22:45:12.684046+00	CM-3605
27	\N	\N	\N	\N	IMS-2026-1732	\N	2026-05-31	\N	\N	2026-02-20 00:16:35.358+00	CM-3605
28	\N	\N	\N	\N	IMS-2026-7632	\N	2026-05-20	\N	\N	2026-02-20 10:06:29.331122+00	CM-3605
25	\N	\N	\N	\N	IMS-2026-9192	\N	2027-02-20	\N	\N	2026-02-19 22:43:50.275113+00	CM-3605
30	\N	\N	\N	\N	IMS-2026-7768	\N	2026-05-22	\N	\N	2026-02-22 12:04:29.240918+00	CM-2618
33	\N	\N	\N	\N	IMS-2026-6661	\N	2026-04-22	\N	\N	2026-02-22 12:20:30.66266+00	CM-3605
\.


--
-- TOC entry 4156 (class 0 OID 19027)
-- Dependencies: 403
-- Data for Name: students; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.students (id, admission_date, full_name, mobile, father_mobile, mother_mobile, standard, batch_time, course, total_fees, paid_amount, pending_amount, roll_number, status, user_id, institute_id, due_dates, course_end_date) FROM stdin;
6	2026-02-17	rakesh jhunjhunwala	1900000000	2900000000	3900000000	8th	12:30:00	algebra	10000	7000	3000	IMS-2026-7697	Active	dc4ca84b-e9e0-497e-bf9a-f40166ce7428	\N	\N	\N
1	2026-02-17	sameer ghadi	8888855555	7777755555	9999988888	15th	14:30:00	Bsc	30000	25000	5000	IMS-2026-4336	Active	\N	CM-1001	\N	\N
2	2026-02-17	rakesh jhujhunwala	1000000000	2000000000	3000000000	9th	10:00:00	algebra	9000	5000	4000	IMS-2026-8528	Active	\N	CM-1001	\N	\N
7	2026-02-18	ketan parekh	1234567890	1233211230	3211233210	7th	11:45:00	spanish language classes	3500	2000	1500	IMS-2026-3949	Active	dc4ca84b-e9e0-497e-bf9a-f40166ce7428	CM-2002	\N	\N
8	2026-02-18	mani shankar	1357913579	2468024680	1021031040	8th	16:30:00	drawing and sketching	15000	10000	5000	IMS-2026-8722	Active	9ccae1e5-29ee-46fb-8f78-7128de725323	CM-1001	\N	\N
25	2026-02-21	Ashish M	2323232320	3434343434	4545454545	12th	12:30:00	geometry	10000	7000	3000	IMS-2026-9192	Active	8acf4dec-4f31-4a9b-8bee-27357658e588	CM-3605	March 2026, April 2026	\N
30	2026-02-22	manish patel	8787878787	5454545454	4343434343	10th	11:30:00	maths	25000	15000	10000	IMS-2026-7768	Active	3e42e9f9-cbd6-4712-9dd5-68fbd59c6604	CM-2618	March 2026, April 2026	\N
21	2026-02-19	pinky patel	1111111111	2222222222	3333333333	10th	11:30:00	maths	25000	11000	14000	IMS-2026-5171	Active	8acf4dec-4f31-4a9b-8bee-27357658e588	CM-3605	March 2026, April 2026	\N
22	2026-02-19	manisha patel	6666666666	5555555555	3333333333	10th	18:30:00	drawing	10000	10000	0	IMS-2026-4728	Active	8acf4dec-4f31-4a9b-8bee-27357658e588	CM-3605	Feb 2026	\N
23	2026-01-01	yogesh d	7979797979	8989898989	6969696969	12th	14:30:00	Accounts	10000	10000	0	IMS-2026-1415	Closed	8acf4dec-4f31-4a9b-8bee-27357658e588	CM-3605		\N
24	2026-02-20	Amrut W	3535353535	4545454545	5555555555	12th	11:30:00	algebra	10000	7000	3000	IMS-2026-5911	Active	8acf4dec-4f31-4a9b-8bee-27357658e588	CM-3605	March 2026, April 2026, May 2026	\N
26	2026-02-20	Amogh S	6464646464	7474747474	8484848484	12th	13:30:00	Physics	10000	4000	6000	IMS-2026-8115	Active	8acf4dec-4f31-4a9b-8bee-27357658e588	CM-3605	March 2026, April 2026, My 2026, June 2026	\N
27	2026-02-20	sanjay I	9797979797	8787878787	7878787878	8th	11:30:00	geography	7500	5000	2500	IMS-2026-1732	Active	8acf4dec-4f31-4a9b-8bee-27357658e588	CM-3605	March 2026	\N
28	2026-02-20	kamlesh rathod	6767676767	7676767676	8686868686	10th	15:30:00	music	30000	20000	10000	IMS-2026-7632	Active	8acf4dec-4f31-4a9b-8bee-27357658e588	CM-3605	March 2026, April 2026	\N
33	2026-02-22	deepak rathod	5955955956	8989898989	7474747474	10th	11:30:00	geometry	25000	20000	5000	IMS-2026-6661	Active	c1b9d561-78a4-44c3-a0eb-2a30741444b7	CM-3605	march 2026	\N
\.


--
-- TOC entry 4154 (class 0 OID 19019)
-- Dependencies: 401
-- Data for Name: teacher_details; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.teacher_details (id, teacher_name, age, gender, joining_date, qualification, subject_taught, salary_offered, institute_id, mobile, rating, full_address, email, experience, status, availability, time_of_slot) FROM stdin;
TCH-8638	sunil v	50	\N	2026-01-01	TESOL	SPOKEN ENGLISH	30000	\N	\N	5	\N	pending@update-me.com	\N	active	no	
TCH-1709	sanjay sengupta	48	\N	2026-01-01	MBA	business economics	30000	CM-3605	\N	5	\N	pending@update-me.com	\N	active	no	
TCH-4767	mukesh bhati	45	\N	2026-02-01	engineer	life insurance basics	40000	CM-3605	911111122222	5	\N	pending@update-me.com	\N	active	no	
TCH-6974	Anthony	55	\N	2026-02-01	Engineer	Maths	45000	CM-3605	911111100000	5	\N	pending@update-me.com	\N	active	no	
TCH-9669	Susan thomas	49	\N	2026-02-10	MBA	chemistry	35000	CM-3605	912222200000	5	\N	pending@update-me.com	\N	active	no	
TCH-9318	George	51	\N	2026-02-12	Electronics engineer	electrical engineering	40000	CM-3605	913333300000	5	\N	pending@update-me.com	\N	active	no	
TCH-8052	Dayanand P	44	\N	2026-02-02	mechanical engineer	TOM	50000	CM-3605	911234567890	5	\N	pending@update-me.com	\N	active	no	
TCH-1437	Zaheer K	48	\N	2026-02-03	Production engineer	Engineering mechanics	65000	CM-3605	912345678901	5	\N	pending@update-me.com	\N	active	no	
TCH-7883	AAA Khan	56	\N	2026-02-04	Chemical engineer	Applied chemistry	38000	CM-3605	913456789012	5	\N	pending@update-me.com	\N	active	no	
TCH-3060	surya yadav	57	Male	2026-02-01	BE,MBA	geometry	49000	CM-3605	9136516298	4.5	Mumbai	surya2gmail.com	6	Active	no	
TCH-9866	abdul qadri	51	Male	2026-02-08	BEd in Maths	Geometry	45000	CM-3605	8888899999	4	Byculla, Mumbai	abdul@gmail.com	10	Active	no	
TCH-6313	sherly george	36	Female	2026-02-15	Bsc in Maths	Geometry	35000	CM-3605	1234568901	4.2	mulund,Mumbai	sherly@gmail.com	7	Active	no	
TCH-7224	krupali patel	43	Female	2026-02-15	BSc	geometry	39000	CM-3605	3333344444	3.9	Dahisar,Mumbai	krupali@gmail.com	3	Active	no	
TCH-4881	sunil v	51	Male	2026-02-02	BE,MBA	geometry	50000	CM-3605	8879267011	5	Kandivali,Mumbai	sunilv@gmail.com	3	Active	no	
TCH-8170	vihaan v	28	Male	2026-02-17	BE	geometry	40000	CM-3605	9999988888	4.1	pune	vihaan@gmail.com	1	Active	no	
TCH-7762	ketan B	39	Male	2026-02-18	BCOM	geometry	35000	CM-3605	3737373737	4.3	Mumbai	ketan@gmail.com	2	Active	no	
TCH-3784	seema joshi	45	Female	2026-02-21	MBA	geometry	28000	CM-3605	3333388888	4	mumbai	seema@gmail.com	3	Active	no	
TCH-3159	xyz	37	Male	2026-02-16	BE	geometry	39000	CM-3605	8888877777	5	mumbai,india	xyz@gmail.com	4	Active	no	
TCH-8976	aman khurana	50	Male	2026-02-01	BE,MBA	geometry	50000	CM-3605	8888899999	5	Mumbai	aman@gmail.com	5	Active	no	
TCH-5045	abdul kalam	60	Male	2026-02-01	BE	geometry	100000	CM-3605	1000020000	4.9	hyderabad,india	abdul@gmail.com	25	Active	no	
TCH-2342	vijay bohat	45	Male	2026-02-01	BE	geometry	45000	CM-3605	7878787878	5	mumbai	vijayb@gmail.com	5	Active	Yes	09:00 AM to 10:00 AM, 10:00 AM to 11:00 AM, 11:00 AM to 12:00 PM
TCH-8139	ajay bohat	34	Male	2026-02-19	BEd	geometry	25000	CM-3605	7474747474	4	mumbai	ajay@gmail.com	1	Active	Yes	09:00 AM to 10:00 AM, 10:00 AM to 11:00 AM, 11:00 AM to 12:00 PM, 12:00 PM to 01:00 PM, 01:00 PM to 02:00 PM, 02:00 PM to 03:00 PM
TCH-7409	kisan v	75	Male	2026-02-17	BALLB	maths	40000	CM-3605	9999944444	4	mumbai	kisanv@gmail.com	10	Active	Yes	10:00 AM to 11:00 AM, 04:00 PM to 05:00 PM, 08:00 PM to 09:00 PM
TCH-1601	Amit dalvi	30	Male	2026-02-20	BE	maths	20000	CM-3605	9898989898	4	ratnagiri,maharashtra, 103,kopargaon	amit@gmail.com	10	Active	No	
\.


--
-- TOC entry 4165 (class 0 OID 21640)
-- Dependencies: 412
-- Data for Name: teacher_payments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.teacher_payments (id, institute_id, teacher_id, full_name, subject_taught, joining_date, payment_date, month_year, amount_paid, pending_amount, created_at, age, qualification, whatsapp) FROM stdin;
891d7ced-39eb-41ec-af3b-d96773913ac1	CM-3605	TCH-1709	sanjay sengupta	business economics	2026-01-01	2026-02-19	February 2026	25000.00	0.00	2026-02-19 15:25:52.23975+00	\N	\N	\N
\.


--
-- TOC entry 4161 (class 0 OID 20343)
-- Dependencies: 408
-- Data for Name: teachers_attendance; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.teachers_attendance (id, institute_id, month_year, teacher_id, full_name, attendance_date, status, created_at) FROM stdin;
2348cc3d-fdca-4e10-a478-010cbce943e2	CM-3605	February 2026	TCH-1709	sanjay sengupta	2026-02-18	Present	2026-02-18 12:10:42.371295+00
3903ee44-5048-4efe-8607-b86942a9e6ec	CM-3605	February 2026	TCH-6974	Anthony	2026-02-20	Present	2026-02-19 22:55:45.086337+00
29624e1f-5cbf-41ee-a92c-8b3f6294391f	CM-3605	February 2026	TCH-9669	Susan thomas	2026-02-20	Absent	2026-02-19 22:57:27.307258+00
9095faa3-1a6e-4239-8198-8cd83b0678a0	CM-3605	February 2026	TCH-1709	sanjay sengupta	2026-02-20	Present	2026-02-20 00:01:58.50274+00
74440f30-21bd-4b9f-9a3c-77f4016393d9	CM-3605	February 2026	TCH-1437	Zaheer K	2026-02-20	Present	2026-02-20 00:23:21.866039+00
4a40af15-37f4-415a-b80b-33ee3c770234	CM-3605	February 2026	TCH-8052	Dayanand P	2026-02-20	Absent	2026-02-20 00:23:41.237493+00
\.


--
-- TOC entry 4220 (class 0 OID 0)
-- Dependencies: 387
-- Name: attendance_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.attendance_id_seq', 11, true);


--
-- TOC entry 4221 (class 0 OID 0)
-- Dependencies: 404
-- Name: batches_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.batches_id_seq', 3, true);


--
-- TOC entry 4222 (class 0 OID 0)
-- Dependencies: 395
-- Name: certificates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.certificates_id_seq', 2, true);


--
-- TOC entry 4223 (class 0 OID 0)
-- Dependencies: 393
-- Name: institute_settings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.institute_settings_id_seq', 1, true);


--
-- TOC entry 4224 (class 0 OID 0)
-- Dependencies: 389
-- Name: leads_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.leads_id_seq', 3, true);


--
-- TOC entry 4225 (class 0 OID 0)
-- Dependencies: 399
-- Name: payment_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.payment_history_id_seq', 29, true);


--
-- TOC entry 4226 (class 0 OID 0)
-- Dependencies: 397
-- Name: performance_tracking_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.performance_tracking_id_seq', 2, true);


--
-- TOC entry 4227 (class 0 OID 0)
-- Dependencies: 402
-- Name: students_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.students_id_seq', 33, true);


--
-- TOC entry 3869 (class 2606 OID 21684)
-- Name: alumni_tracker alumni_tracker_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.alumni_tracker
    ADD CONSTRAINT alumni_tracker_pkey PRIMARY KEY (id);


--
-- TOC entry 3816 (class 2606 OID 17516)
-- Name: attendance attendance_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_pkey PRIMARY KEY (id);


--
-- TOC entry 3850 (class 2606 OID 19048)
-- Name: batches batches_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.batches
    ADD CONSTRAINT batches_pkey PRIMARY KEY (id);


--
-- TOC entry 3828 (class 2606 OID 17686)
-- Name: certificates certificates_cert_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificates
    ADD CONSTRAINT certificates_cert_number_key UNIQUE (cert_number);


--
-- TOC entry 3830 (class 2606 OID 17684)
-- Name: certificates certificates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificates
    ADD CONSTRAINT certificates_pkey PRIMARY KEY (id);


--
-- TOC entry 3882 (class 2606 OID 23031)
-- Name: class_bookings class_bookings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.class_bookings
    ADD CONSTRAINT class_bookings_pkey PRIMARY KEY (id);


--
-- TOC entry 3856 (class 2606 OID 20342)
-- Name: exam exam_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.exam
    ADD CONSTRAINT exam_pkey PRIMARY KEY (id);


--
-- TOC entry 3852 (class 2606 OID 19091)
-- Name: expenses expenses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.expenses
    ADD CONSTRAINT expenses_pkey PRIMARY KEY (month_year);


--
-- TOC entry 3864 (class 2606 OID 20450)
-- Name: institute_calendar institute_calendar_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.institute_calendar
    ADD CONSTRAINT institute_calendar_pkey PRIMARY KEY (id);


--
-- TOC entry 3826 (class 2606 OID 17652)
-- Name: institute_settings institute_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.institute_settings
    ADD CONSTRAINT institute_settings_pkey PRIMARY KEY (id);


--
-- TOC entry 3875 (class 2606 OID 21723)
-- Name: inventory_master inventory_master_institute_id_item_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory_master
    ADD CONSTRAINT inventory_master_institute_id_item_name_key UNIQUE (institute_id, item_name);


--
-- TOC entry 3877 (class 2606 OID 21721)
-- Name: inventory_master inventory_master_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory_master
    ADD CONSTRAINT inventory_master_pkey PRIMARY KEY (id);


--
-- TOC entry 3880 (class 2606 OID 21733)
-- Name: inventory_sales inventory_sales_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory_sales
    ADD CONSTRAINT inventory_sales_pkey PRIMARY KEY (id);


--
-- TOC entry 3873 (class 2606 OID 21709)
-- Name: inventory_tracker inventory_tracker_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory_tracker
    ADD CONSTRAINT inventory_tracker_pkey PRIMARY KEY (id);


--
-- TOC entry 3818 (class 2606 OID 17532)
-- Name: leads leads_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.leads
    ADD CONSTRAINT leads_pkey PRIMARY KEY (id);


--
-- TOC entry 3895 (class 2606 OID 24290)
-- Name: list list_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.list
    ADD CONSTRAINT list_pkey PRIMARY KEY (id);


--
-- TOC entry 3862 (class 2606 OID 20427)
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- TOC entry 3839 (class 2606 OID 18876)
-- Name: payment_history payment_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payment_history
    ADD CONSTRAINT payment_history_pkey PRIMARY KEY (id);


--
-- TOC entry 3832 (class 2606 OID 17703)
-- Name: performance_tracking performance_tracking_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.performance_tracking
    ADD CONSTRAINT performance_tracking_pkey PRIMARY KEY (id);


--
-- TOC entry 3834 (class 2606 OID 20373)
-- Name: performance_tracking performance_tracking_roll_inst_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.performance_tracking
    ADD CONSTRAINT performance_tracking_roll_inst_unique UNIQUE (roll_number, institute_id);


--
-- TOC entry 3824 (class 2606 OID 17632)
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- TOC entry 3889 (class 2606 OID 24265)
-- Name: ptm_schedule ptm_schedule_institute_id_roll_number_month_year_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ptm_schedule
    ADD CONSTRAINT ptm_schedule_institute_id_roll_number_month_year_key UNIQUE (institute_id, roll_number, month_year);


--
-- TOC entry 3891 (class 2606 OID 24263)
-- Name: ptm_schedule ptm_schedule_institute_id_teacher_id_ptm_date_slot_time_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ptm_schedule
    ADD CONSTRAINT ptm_schedule_institute_id_teacher_id_ptm_date_slot_time_key UNIQUE (institute_id, teacher_id, ptm_date, slot_time);


--
-- TOC entry 3893 (class 2606 OID 24261)
-- Name: ptm_schedule ptm_schedule_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ptm_schedule
    ADD CONSTRAINT ptm_schedule_pkey PRIMARY KEY (id);


--
-- TOC entry 3885 (class 2606 OID 24225)
-- Name: scholarships scholarships_institute_id_roll_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scholarships
    ADD CONSTRAINT scholarships_institute_id_roll_number_key UNIQUE (institute_id, roll_number);


--
-- TOC entry 3887 (class 2606 OID 24223)
-- Name: scholarships scholarships_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scholarships
    ADD CONSTRAINT scholarships_pkey PRIMARY KEY (id);


--
-- TOC entry 3860 (class 2606 OID 20391)
-- Name: student_allocations student_allocations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_allocations
    ADD CONSTRAINT student_allocations_pkey PRIMARY KEY (id);


--
-- TOC entry 3820 (class 2606 OID 17575)
-- Name: student_details student_details_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_details
    ADD CONSTRAINT student_details_pkey PRIMARY KEY (student_id);


--
-- TOC entry 3822 (class 2606 OID 17577)
-- Name: student_details student_details_roll_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_details
    ADD CONSTRAINT student_details_roll_number_key UNIQUE (roll_number);


--
-- TOC entry 3844 (class 2606 OID 19039)
-- Name: students students_mobile_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_mobile_key UNIQUE (mobile);


--
-- TOC entry 3846 (class 2606 OID 19037)
-- Name: students students_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_pkey PRIMARY KEY (id);


--
-- TOC entry 3848 (class 2606 OID 21592)
-- Name: students students_roll_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_roll_number_key UNIQUE (roll_number);


--
-- TOC entry 3841 (class 2606 OID 19025)
-- Name: teacher_details teacher_details_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teacher_details
    ADD CONSTRAINT teacher_details_pkey PRIMARY KEY (id);


--
-- TOC entry 3867 (class 2606 OID 21651)
-- Name: teacher_payments teacher_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teacher_payments
    ADD CONSTRAINT teacher_payments_pkey PRIMARY KEY (id);


--
-- TOC entry 3858 (class 2606 OID 20351)
-- Name: teachers_attendance teachers_attendance_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teachers_attendance
    ADD CONSTRAINT teachers_attendance_pkey PRIMARY KEY (id);


--
-- TOC entry 3871 (class 2606 OID 21686)
-- Name: alumni_tracker unique_alumni; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.alumni_tracker
    ADD CONSTRAINT unique_alumni UNIQUE (roll_number, institute_id);


--
-- TOC entry 3854 (class 2606 OID 21758)
-- Name: expenses unique_month_inst; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.expenses
    ADD CONSTRAINT unique_month_inst UNIQUE (institute_id, month_year);


--
-- TOC entry 3836 (class 2606 OID 17723)
-- Name: performance_tracking unique_student_performance; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.performance_tracking
    ADD CONSTRAINT unique_student_performance UNIQUE (student_id);


--
-- TOC entry 3878 (class 1259 OID 21775)
-- Name: idx_inv_month_year; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_inv_month_year ON public.inventory_sales USING btree (month_year);


--
-- TOC entry 3837 (class 1259 OID 19159)
-- Name: idx_payments_inst; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_payments_inst ON public.payment_history USING btree (institute_id);


--
-- TOC entry 3842 (class 1259 OID 19158)
-- Name: idx_students_inst; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_students_inst ON public.students USING btree (institute_id);


--
-- TOC entry 3865 (class 1259 OID 21658)
-- Name: idx_teacher_payment_search; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_teacher_payment_search ON public.teacher_payments USING btree (teacher_id, month_year);


--
-- TOC entry 3883 (class 1259 OID 23032)
-- Name: unique_teacher_slot; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX unique_teacher_slot ON public.class_bookings USING btree (institute_id, teacher_id, booking_date, time_slot);


--
-- TOC entry 3898 (class 2606 OID 21593)
-- Name: payment_history fk_student; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payment_history
    ADD CONSTRAINT fk_student FOREIGN KEY (roll_number) REFERENCES public.students(roll_number) ON DELETE CASCADE;


--
-- TOC entry 3896 (class 2606 OID 19127)
-- Name: student_details fk_student_details_students; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_details
    ADD CONSTRAINT fk_student_details_students FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- TOC entry 3899 (class 2606 OID 21652)
-- Name: teacher_payments fk_teacher; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teacher_payments
    ADD CONSTRAINT fk_teacher FOREIGN KEY (teacher_id) REFERENCES public.teacher_details(id) ON DELETE CASCADE;


--
-- TOC entry 3897 (class 2606 OID 17583)
-- Name: student_details student_details_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_details
    ADD CONSTRAINT student_details_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- TOC entry 4121 (class 3256 OID 20392)
-- Name: student_allocations Allocation Isolation; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allocation Isolation" ON public.student_allocations TO authenticated USING ((institute_id = public.get_my_institute_id())) WITH CHECK ((institute_id = public.get_my_institute_id()));


--
-- TOC entry 4081 (class 3256 OID 17633)
-- Name: profiles Allow all inserts; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow all inserts" ON public.profiles FOR INSERT WITH CHECK (true);


--
-- TOC entry 4087 (class 3256 OID 18966)
-- Name: attendance Allow authenticated users to manage attendance; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated users to manage attendance" ON public.attendance TO authenticated USING (true) WITH CHECK (true);


--
-- TOC entry 4086 (class 3256 OID 18960)
-- Name: payment_history Allow authenticated users to manage payment_history; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated users to manage payment_history" ON public.payment_history TO authenticated USING (true) WITH CHECK (true);


--
-- TOC entry 4088 (class 3256 OID 18968)
-- Name: student_details Allow authenticated users to manage student_details; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated users to manage student_details" ON public.student_details TO authenticated USING (true) WITH CHECK (true);


--
-- TOC entry 4082 (class 3256 OID 17634)
-- Name: profiles Allow individual select; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow individual select" ON public.profiles FOR SELECT USING (true);


--
-- TOC entry 4135 (class 3256 OID 24189)
-- Name: teacher_details Allow teacher to update availability and time slots; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow teacher to update availability and time slots" ON public.teacher_details FOR UPDATE TO authenticated USING ((institute_id = public.get_my_institute())) WITH CHECK ((institute_id = public.get_my_institute()));


--
-- TOC entry 4138 (class 3256 OID 24291)
-- Name: list Enable access for authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable access for authenticated users" ON public.list USING ((auth.role() = 'authenticated'::text));


--
-- TOC entry 4125 (class 3256 OID 20453)
-- Name: institute_calendar Enable delete for all users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable delete for all users" ON public.institute_calendar FOR DELETE USING (true);


--
-- TOC entry 4124 (class 3256 OID 20452)
-- Name: institute_calendar Enable insert for all users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable insert for all users" ON public.institute_calendar FOR INSERT WITH CHECK (true);


--
-- TOC entry 4123 (class 3256 OID 20451)
-- Name: institute_calendar Enable read access for all users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable read access for all users" ON public.institute_calendar FOR SELECT USING (true);


--
-- TOC entry 4118 (class 3256 OID 20352)
-- Name: exam Exam Isolation; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Exam Isolation" ON public.exam TO authenticated USING ((institute_id = public.get_my_institute_id())) WITH CHECK ((institute_id = public.get_my_institute_id()));


--
-- TOC entry 4107 (class 3256 OID 19173)
-- Name: attendance Institute Isolation; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institute Isolation" ON public.attendance TO authenticated USING ((institute_id = public.get_my_institute())) WITH CHECK ((institute_id = public.get_my_institute()));


--
-- TOC entry 4108 (class 3256 OID 19174)
-- Name: batches Institute Isolation; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institute Isolation" ON public.batches TO authenticated USING ((institute_id = public.get_my_institute())) WITH CHECK ((institute_id = public.get_my_institute()));


--
-- TOC entry 4109 (class 3256 OID 19175)
-- Name: certificates Institute Isolation; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institute Isolation" ON public.certificates TO authenticated USING ((institute_id = public.get_my_institute())) WITH CHECK ((institute_id = public.get_my_institute()));


--
-- TOC entry 4110 (class 3256 OID 19176)
-- Name: expenses Institute Isolation; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institute Isolation" ON public.expenses TO authenticated USING ((institute_id = public.get_my_institute())) WITH CHECK ((institute_id = public.get_my_institute()));


--
-- TOC entry 4111 (class 3256 OID 19177)
-- Name: institute_settings Institute Isolation; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institute Isolation" ON public.institute_settings TO authenticated USING ((institute_id = public.get_my_institute())) WITH CHECK ((institute_id = public.get_my_institute()));


--
-- TOC entry 4112 (class 3256 OID 19178)
-- Name: leads Institute Isolation; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institute Isolation" ON public.leads TO authenticated USING ((institute_id = public.get_my_institute())) WITH CHECK ((institute_id = public.get_my_institute()));


--
-- TOC entry 4113 (class 3256 OID 19179)
-- Name: payment_history Institute Isolation; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institute Isolation" ON public.payment_history TO authenticated USING ((institute_id = public.get_my_institute())) WITH CHECK ((institute_id = public.get_my_institute()));


--
-- TOC entry 4114 (class 3256 OID 19180)
-- Name: performance_tracking Institute Isolation; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institute Isolation" ON public.performance_tracking TO authenticated USING ((institute_id = public.get_my_institute())) WITH CHECK ((institute_id = public.get_my_institute()));


--
-- TOC entry 4115 (class 3256 OID 19181)
-- Name: student_details Institute Isolation; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institute Isolation" ON public.student_details TO authenticated USING ((institute_id = public.get_my_institute())) WITH CHECK ((institute_id = public.get_my_institute()));


--
-- TOC entry 4116 (class 3256 OID 19182)
-- Name: students Institute Isolation; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institute Isolation" ON public.students TO authenticated USING ((institute_id = public.get_my_institute())) WITH CHECK ((institute_id = public.get_my_institute()));


--
-- TOC entry 4117 (class 3256 OID 19183)
-- Name: teacher_details Institute Isolation; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institute Isolation" ON public.teacher_details TO authenticated USING ((institute_id = public.get_my_institute())) WITH CHECK ((institute_id = public.get_my_institute()));


--
-- TOC entry 4137 (class 3256 OID 24266)
-- Name: ptm_schedule Institute Isolation Policy for PTM; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institute Isolation Policy for PTM" ON public.ptm_schedule USING ((institute_id IN ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid()))));


--
-- TOC entry 4136 (class 3256 OID 24226)
-- Name: scholarships Institute Isolation Policy for Scholarships; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institute Isolation Policy for Scholarships" ON public.scholarships USING ((institute_id IN ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid()))));


--
-- TOC entry 4095 (class 3256 OID 19138)
-- Name: attendance Institute_Isolation_Policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institute_Isolation_Policy" ON public.attendance USING ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid())))) WITH CHECK ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid()))));


--
-- TOC entry 4096 (class 3256 OID 19140)
-- Name: batches Institute_Isolation_Policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institute_Isolation_Policy" ON public.batches USING ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid())))) WITH CHECK ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid()))));


--
-- TOC entry 4103 (class 3256 OID 19152)
-- Name: certificates Institute_Isolation_Policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institute_Isolation_Policy" ON public.certificates USING ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid())))) WITH CHECK ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid()))));


--
-- TOC entry 4098 (class 3256 OID 19144)
-- Name: expenses Institute_Isolation_Policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institute_Isolation_Policy" ON public.expenses USING ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid())))) WITH CHECK ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid()))));


--
-- TOC entry 4104 (class 3256 OID 19154)
-- Name: institute_settings Institute_Isolation_Policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institute_Isolation_Policy" ON public.institute_settings USING ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid())))) WITH CHECK ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid()))));


--
-- TOC entry 4100 (class 3256 OID 19146)
-- Name: leads Institute_Isolation_Policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institute_Isolation_Policy" ON public.leads USING ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid())))) WITH CHECK ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid()))));


--
-- TOC entry 4097 (class 3256 OID 19142)
-- Name: payment_history Institute_Isolation_Policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institute_Isolation_Policy" ON public.payment_history USING ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid())))) WITH CHECK ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid()))));


--
-- TOC entry 4102 (class 3256 OID 19150)
-- Name: performance_tracking Institute_Isolation_Policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institute_Isolation_Policy" ON public.performance_tracking USING ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid())))) WITH CHECK ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid()))));


--
-- TOC entry 4094 (class 3256 OID 19136)
-- Name: student_details Institute_Isolation_Policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institute_Isolation_Policy" ON public.student_details USING ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid())))) WITH CHECK ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid()))));


--
-- TOC entry 4093 (class 3256 OID 19134)
-- Name: students Institute_Isolation_Policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institute_Isolation_Policy" ON public.students USING ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid())))) WITH CHECK ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid()))));


--
-- TOC entry 4101 (class 3256 OID 19148)
-- Name: teacher_details Institute_Isolation_Policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institute_Isolation_Policy" ON public.teacher_details USING ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid())))) WITH CHECK ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid()))));


--
-- TOC entry 4127 (class 3256 OID 21687)
-- Name: alumni_tracker Institutes can manage their own alumni; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institutes can manage their own alumni" ON public.alumni_tracker USING ((institute_id = institute_id));


--
-- TOC entry 4126 (class 3256 OID 21657)
-- Name: teacher_payments Institutes can only access their own teacher payments; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institutes can only access their own teacher payments" ON public.teacher_payments USING ((institute_id = institute_id));


--
-- TOC entry 4128 (class 3256 OID 21710)
-- Name: inventory_tracker Institutes manage own inventory; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Institutes manage own inventory" ON public.inventory_tracker USING ((institute_id = institute_id));


--
-- TOC entry 4129 (class 3256 OID 21734)
-- Name: inventory_master Manage Master; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Manage Master" ON public.inventory_master USING ((institute_id = institute_id));


--
-- TOC entry 4130 (class 3256 OID 21735)
-- Name: inventory_sales Manage Sales; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Manage Sales" ON public.inventory_sales USING ((institute_id = institute_id));


--
-- TOC entry 4092 (class 3256 OID 19092)
-- Name: expenses Manage expenses; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Manage expenses" ON public.expenses TO authenticated USING (true) WITH CHECK (true);


--
-- TOC entry 4091 (class 3256 OID 19069)
-- Name: leads Manage leads; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Manage leads" ON public.leads TO authenticated USING (true) WITH CHECK (true);


--
-- TOC entry 4106 (class 3256 OID 19171)
-- Name: profiles Manage own profile; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Manage own profile" ON public.profiles USING ((auth.uid() = id));


--
-- TOC entry 4122 (class 3256 OID 20428)
-- Name: messages Message Isolation; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Message Isolation" ON public.messages TO authenticated USING ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid())))) WITH CHECK ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid()))));


--
-- TOC entry 4078 (class 3256 OID 17606)
-- Name: leads Only Owner can manage leads; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Only Owner can manage leads" ON public.leads USING ((public.get_my_role() = 'Owner'::text));


--
-- TOC entry 4083 (class 3256 OID 17653)
-- Name: institute_settings Owners manage settings; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Owners manage settings" ON public.institute_settings USING (true);


--
-- TOC entry 4120 (class 3256 OID 20367)
-- Name: performance_tracking Performance Tracking Isolation; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Performance Tracking Isolation" ON public.performance_tracking TO authenticated USING ((institute_id = public.get_my_institute_id())) WITH CHECK ((institute_id = public.get_my_institute_id()));


--
-- TOC entry 4080 (class 3256 OID 17609)
-- Name: attendance Staff can manage all attendance; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Staff can manage all attendance" ON public.attendance USING ((public.get_my_role() = ANY (ARRAY['Owner'::text, 'Teacher'::text])));


--
-- TOC entry 4076 (class 3256 OID 17602)
-- Name: student_details Staff manage all student details; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Staff manage all student details" ON public.student_details USING ((public.get_my_role() = ANY (ARRAY['Owner'::text, 'Teacher'::text])));


--
-- TOC entry 4084 (class 3256 OID 17692)
-- Name: certificates Staff manage certificates; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Staff manage certificates" ON public.certificates USING (true);


--
-- TOC entry 4085 (class 3256 OID 17709)
-- Name: performance_tracking Staff manage performance; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Staff manage performance" ON public.performance_tracking USING (true);


--
-- TOC entry 4079 (class 3256 OID 17608)
-- Name: attendance Students can view own attendance; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Students can view own attendance" ON public.attendance FOR SELECT USING ((auth.uid() = user_id));


--
-- TOC entry 4074 (class 3256 OID 17593)
-- Name: student_details Students can view own details; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Students can view own details" ON public.student_details FOR SELECT USING ((auth.uid() = user_id));


--
-- TOC entry 4075 (class 3256 OID 17601)
-- Name: student_details Students view own extended details; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Students view own extended details" ON public.student_details FOR SELECT USING ((auth.uid() = user_id));


--
-- TOC entry 4119 (class 3256 OID 20353)
-- Name: teachers_attendance Teacher Attendance Isolation; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Teacher Attendance Isolation" ON public.teachers_attendance TO authenticated USING ((institute_id = public.get_my_institute_id())) WITH CHECK ((institute_id = public.get_my_institute_id()));


--
-- TOC entry 4105 (class 3256 OID 19156)
-- Name: profiles Users can see own profile; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can see own profile" ON public.profiles FOR SELECT USING ((id = auth.uid()));


--
-- TOC entry 4099 (class 3256 OID 19157)
-- Name: profiles Users can update own profile; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING ((id = auth.uid()));


--
-- TOC entry 4066 (class 0 OID 21675)
-- Dependencies: 413
-- Name: alumni_tracker; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.alumni_tracker ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 4048 (class 0 OID 17507)
-- Dependencies: 388
-- Name: attendance; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 4077 (class 3256 OID 19051)
-- Name: batches auth_batches; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY auth_batches ON public.batches TO authenticated USING (true) WITH CHECK (true);


--
-- TOC entry 4090 (class 3256 OID 19050)
-- Name: students auth_students; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY auth_students ON public.students TO authenticated USING (true) WITH CHECK (true);


--
-- TOC entry 4089 (class 3256 OID 19049)
-- Name: teacher_details auth_teacher; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY auth_teacher ON public.teacher_details TO authenticated USING (true) WITH CHECK (true);


--
-- TOC entry 4058 (class 0 OID 19041)
-- Dependencies: 405
-- Name: batches; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.batches ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 4053 (class 0 OID 17676)
-- Dependencies: 396
-- Name: certificates; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.certificates ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 4070 (class 0 OID 23023)
-- Dependencies: 417
-- Name: class_bookings; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.class_bookings ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 4134 (class 3256 OID 23036)
-- Name: class_bookings delete_own_bookings; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY delete_own_bookings ON public.class_bookings FOR DELETE USING ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid()))));


--
-- TOC entry 4060 (class 0 OID 20334)
-- Dependencies: 407
-- Name: exam; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.exam ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 4059 (class 0 OID 19072)
-- Dependencies: 406
-- Name: expenses; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 4132 (class 3256 OID 23034)
-- Name: class_bookings insert_own_bookings; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY insert_own_bookings ON public.class_bookings FOR INSERT WITH CHECK ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid()))));


--
-- TOC entry 4064 (class 0 OID 20442)
-- Dependencies: 411
-- Name: institute_calendar; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.institute_calendar ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 4052 (class 0 OID 17642)
-- Dependencies: 394
-- Name: institute_settings; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.institute_settings ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 4068 (class 0 OID 21712)
-- Dependencies: 415
-- Name: inventory_master; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.inventory_master ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 4069 (class 0 OID 21724)
-- Dependencies: 416
-- Name: inventory_sales; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.inventory_sales ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 4067 (class 0 OID 21695)
-- Dependencies: 414
-- Name: inventory_tracker; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.inventory_tracker ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 4049 (class 0 OID 17523)
-- Dependencies: 390
-- Name: leads; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 4073 (class 0 OID 24282)
-- Dependencies: 420
-- Name: list; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.list ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 4063 (class 0 OID 20419)
-- Dependencies: 410
-- Name: messages; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 4055 (class 0 OID 18869)
-- Dependencies: 400
-- Name: payment_history; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.payment_history ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 4054 (class 0 OID 17694)
-- Dependencies: 398
-- Name: performance_tracking; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.performance_tracking ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 4051 (class 0 OID 17625)
-- Dependencies: 392
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 4072 (class 0 OID 24252)
-- Dependencies: 419
-- Name: ptm_schedule; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.ptm_schedule ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 4071 (class 0 OID 24210)
-- Dependencies: 418
-- Name: scholarships; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.scholarships ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 4131 (class 3256 OID 23033)
-- Name: class_bookings select_own_bookings; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY select_own_bookings ON public.class_bookings FOR SELECT USING ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid()))));


--
-- TOC entry 4062 (class 0 OID 20383)
-- Dependencies: 409
-- Name: student_allocations; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.student_allocations ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 4050 (class 0 OID 17567)
-- Dependencies: 391
-- Name: student_details; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.student_details ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 4057 (class 0 OID 19027)
-- Dependencies: 403
-- Name: students; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 4056 (class 0 OID 19019)
-- Dependencies: 401
-- Name: teacher_details; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.teacher_details ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 4065 (class 0 OID 21640)
-- Dependencies: 412
-- Name: teacher_payments; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.teacher_payments ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 4061 (class 0 OID 20343)
-- Dependencies: 408
-- Name: teachers_attendance; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.teachers_attendance ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 4133 (class 3256 OID 23035)
-- Name: class_bookings update_own_bookings; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY update_own_bookings ON public.class_bookings FOR UPDATE USING ((institute_id = ( SELECT profiles.institute_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid()))));


--
-- TOC entry 4180 (class 0 OID 0)
-- Dependencies: 38
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--
-- TOC entry 4181 (class 0 OID 0)
-- Dependencies: 517
-- Name: FUNCTION auto_sync_payment(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.auto_sync_payment() TO anon;
GRANT ALL ON FUNCTION public.auto_sync_payment() TO authenticated;
GRANT ALL ON FUNCTION public.auto_sync_payment() TO service_role;


--
-- TOC entry 4182 (class 0 OID 0)
-- Dependencies: 460
-- Name: FUNCTION get_my_institute(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_my_institute() TO anon;
GRANT ALL ON FUNCTION public.get_my_institute() TO authenticated;
GRANT ALL ON FUNCTION public.get_my_institute() TO service_role;


--
-- TOC entry 4183 (class 0 OID 0)
-- Dependencies: 472
-- Name: FUNCTION get_my_institute_id(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_my_institute_id() TO anon;
GRANT ALL ON FUNCTION public.get_my_institute_id() TO authenticated;
GRANT ALL ON FUNCTION public.get_my_institute_id() TO service_role;


--
-- TOC entry 4184 (class 0 OID 0)
-- Dependencies: 425
-- Name: FUNCTION get_my_role(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_my_role() TO anon;
GRANT ALL ON FUNCTION public.get_my_role() TO authenticated;
GRANT ALL ON FUNCTION public.get_my_role() TO service_role;


--
-- TOC entry 4185 (class 0 OID 0)
-- Dependencies: 440
-- Name: FUNCTION rls_auto_enable(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.rls_auto_enable() TO anon;
GRANT ALL ON FUNCTION public.rls_auto_enable() TO authenticated;
GRANT ALL ON FUNCTION public.rls_auto_enable() TO service_role;


--
-- TOC entry 4186 (class 0 OID 0)
-- Dependencies: 413
-- Name: TABLE alumni_tracker; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.alumni_tracker TO anon;
GRANT ALL ON TABLE public.alumni_tracker TO authenticated;
GRANT ALL ON TABLE public.alumni_tracker TO service_role;


--
-- TOC entry 4187 (class 0 OID 0)
-- Dependencies: 388
-- Name: TABLE attendance; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.attendance TO anon;
GRANT ALL ON TABLE public.attendance TO authenticated;
GRANT ALL ON TABLE public.attendance TO service_role;


--
-- TOC entry 4188 (class 0 OID 0)
-- Dependencies: 387
-- Name: SEQUENCE attendance_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.attendance_id_seq TO anon;
GRANT ALL ON SEQUENCE public.attendance_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.attendance_id_seq TO service_role;


--
-- TOC entry 4189 (class 0 OID 0)
-- Dependencies: 405
-- Name: TABLE batches; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.batches TO anon;
GRANT ALL ON TABLE public.batches TO authenticated;
GRANT ALL ON TABLE public.batches TO service_role;


--
-- TOC entry 4190 (class 0 OID 0)
-- Dependencies: 404
-- Name: SEQUENCE batches_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.batches_id_seq TO anon;
GRANT ALL ON SEQUENCE public.batches_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.batches_id_seq TO service_role;


--
-- TOC entry 4191 (class 0 OID 0)
-- Dependencies: 396
-- Name: TABLE certificates; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.certificates TO anon;
GRANT ALL ON TABLE public.certificates TO authenticated;
GRANT ALL ON TABLE public.certificates TO service_role;


--
-- TOC entry 4192 (class 0 OID 0)
-- Dependencies: 395
-- Name: SEQUENCE certificates_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.certificates_id_seq TO anon;
GRANT ALL ON SEQUENCE public.certificates_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.certificates_id_seq TO service_role;


--
-- TOC entry 4193 (class 0 OID 0)
-- Dependencies: 417
-- Name: TABLE class_bookings; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.class_bookings TO anon;
GRANT ALL ON TABLE public.class_bookings TO authenticated;
GRANT ALL ON TABLE public.class_bookings TO service_role;


--
-- TOC entry 4194 (class 0 OID 0)
-- Dependencies: 407
-- Name: TABLE exam; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.exam TO anon;
GRANT ALL ON TABLE public.exam TO authenticated;
GRANT ALL ON TABLE public.exam TO service_role;


--
-- TOC entry 4195 (class 0 OID 0)
-- Dependencies: 406
-- Name: TABLE expenses; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.expenses TO anon;
GRANT ALL ON TABLE public.expenses TO authenticated;
GRANT ALL ON TABLE public.expenses TO service_role;


--
-- TOC entry 4196 (class 0 OID 0)
-- Dependencies: 411
-- Name: TABLE institute_calendar; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.institute_calendar TO anon;
GRANT ALL ON TABLE public.institute_calendar TO authenticated;
GRANT ALL ON TABLE public.institute_calendar TO service_role;


--
-- TOC entry 4197 (class 0 OID 0)
-- Dependencies: 394
-- Name: TABLE institute_settings; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.institute_settings TO anon;
GRANT ALL ON TABLE public.institute_settings TO authenticated;
GRANT ALL ON TABLE public.institute_settings TO service_role;


--
-- TOC entry 4198 (class 0 OID 0)
-- Dependencies: 393
-- Name: SEQUENCE institute_settings_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.institute_settings_id_seq TO anon;
GRANT ALL ON SEQUENCE public.institute_settings_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.institute_settings_id_seq TO service_role;


--
-- TOC entry 4199 (class 0 OID 0)
-- Dependencies: 415
-- Name: TABLE inventory_master; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.inventory_master TO anon;
GRANT ALL ON TABLE public.inventory_master TO authenticated;
GRANT ALL ON TABLE public.inventory_master TO service_role;


--
-- TOC entry 4200 (class 0 OID 0)
-- Dependencies: 416
-- Name: TABLE inventory_sales; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.inventory_sales TO anon;
GRANT ALL ON TABLE public.inventory_sales TO authenticated;
GRANT ALL ON TABLE public.inventory_sales TO service_role;


--
-- TOC entry 4201 (class 0 OID 0)
-- Dependencies: 414
-- Name: TABLE inventory_tracker; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.inventory_tracker TO anon;
GRANT ALL ON TABLE public.inventory_tracker TO authenticated;
GRANT ALL ON TABLE public.inventory_tracker TO service_role;


--
-- TOC entry 4202 (class 0 OID 0)
-- Dependencies: 390
-- Name: TABLE leads; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.leads TO anon;
GRANT ALL ON TABLE public.leads TO authenticated;
GRANT ALL ON TABLE public.leads TO service_role;


--
-- TOC entry 4203 (class 0 OID 0)
-- Dependencies: 389
-- Name: SEQUENCE leads_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.leads_id_seq TO anon;
GRANT ALL ON SEQUENCE public.leads_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.leads_id_seq TO service_role;


--
-- TOC entry 4204 (class 0 OID 0)
-- Dependencies: 420
-- Name: TABLE list; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.list TO anon;
GRANT ALL ON TABLE public.list TO authenticated;
GRANT ALL ON TABLE public.list TO service_role;


--
-- TOC entry 4205 (class 0 OID 0)
-- Dependencies: 410
-- Name: TABLE messages; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.messages TO anon;
GRANT ALL ON TABLE public.messages TO authenticated;
GRANT ALL ON TABLE public.messages TO service_role;


--
-- TOC entry 4206 (class 0 OID 0)
-- Dependencies: 400
-- Name: TABLE payment_history; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.payment_history TO anon;
GRANT ALL ON TABLE public.payment_history TO authenticated;
GRANT ALL ON TABLE public.payment_history TO service_role;


--
-- TOC entry 4207 (class 0 OID 0)
-- Dependencies: 399
-- Name: SEQUENCE payment_history_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.payment_history_id_seq TO anon;
GRANT ALL ON SEQUENCE public.payment_history_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.payment_history_id_seq TO service_role;


--
-- TOC entry 4208 (class 0 OID 0)
-- Dependencies: 398
-- Name: TABLE performance_tracking; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.performance_tracking TO anon;
GRANT ALL ON TABLE public.performance_tracking TO authenticated;
GRANT ALL ON TABLE public.performance_tracking TO service_role;


--
-- TOC entry 4209 (class 0 OID 0)
-- Dependencies: 397
-- Name: SEQUENCE performance_tracking_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.performance_tracking_id_seq TO anon;
GRANT ALL ON SEQUENCE public.performance_tracking_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.performance_tracking_id_seq TO service_role;


--
-- TOC entry 4210 (class 0 OID 0)
-- Dependencies: 392
-- Name: TABLE profiles; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.profiles TO anon;
GRANT ALL ON TABLE public.profiles TO authenticated;
GRANT ALL ON TABLE public.profiles TO service_role;


--
-- TOC entry 4211 (class 0 OID 0)
-- Dependencies: 419
-- Name: TABLE ptm_schedule; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.ptm_schedule TO anon;
GRANT ALL ON TABLE public.ptm_schedule TO authenticated;
GRANT ALL ON TABLE public.ptm_schedule TO service_role;


--
-- TOC entry 4212 (class 0 OID 0)
-- Dependencies: 418
-- Name: TABLE scholarships; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.scholarships TO anon;
GRANT ALL ON TABLE public.scholarships TO authenticated;
GRANT ALL ON TABLE public.scholarships TO service_role;


--
-- TOC entry 4213 (class 0 OID 0)
-- Dependencies: 409
-- Name: TABLE student_allocations; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.student_allocations TO anon;
GRANT ALL ON TABLE public.student_allocations TO authenticated;
GRANT ALL ON TABLE public.student_allocations TO service_role;


--
-- TOC entry 4214 (class 0 OID 0)
-- Dependencies: 391
-- Name: TABLE student_details; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.student_details TO anon;
GRANT ALL ON TABLE public.student_details TO authenticated;
GRANT ALL ON TABLE public.student_details TO service_role;


--
-- TOC entry 4215 (class 0 OID 0)
-- Dependencies: 403
-- Name: TABLE students; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.students TO anon;
GRANT ALL ON TABLE public.students TO authenticated;
GRANT ALL ON TABLE public.students TO service_role;


--
-- TOC entry 4216 (class 0 OID 0)
-- Dependencies: 402
-- Name: SEQUENCE students_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.students_id_seq TO anon;
GRANT ALL ON SEQUENCE public.students_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.students_id_seq TO service_role;


--
-- TOC entry 4217 (class 0 OID 0)
-- Dependencies: 401
-- Name: TABLE teacher_details; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.teacher_details TO anon;
GRANT ALL ON TABLE public.teacher_details TO authenticated;
GRANT ALL ON TABLE public.teacher_details TO service_role;


--
-- TOC entry 4218 (class 0 OID 0)
-- Dependencies: 412
-- Name: TABLE teacher_payments; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.teacher_payments TO anon;
GRANT ALL ON TABLE public.teacher_payments TO authenticated;
GRANT ALL ON TABLE public.teacher_payments TO service_role;


--
-- TOC entry 4219 (class 0 OID 0)
-- Dependencies: 408
-- Name: TABLE teachers_attendance; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.teachers_attendance TO anon;
GRANT ALL ON TABLE public.teachers_attendance TO authenticated;
GRANT ALL ON TABLE public.teachers_attendance TO service_role;


--
-- TOC entry 2528 (class 826 OID 16490)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- TOC entry 2529 (class 826 OID 16491)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- TOC entry 2527 (class 826 OID 16489)
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- TOC entry 2531 (class 826 OID 16493)
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- TOC entry 2526 (class 826 OID 16488)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--
-- TOC entry 2530 (class 826 OID 16492)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO service_role;


-- Completed on 2026-02-23 11:15:50

--
-- PostgreSQL database dump complete
--

