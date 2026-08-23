--
-- PostgreSQL database dump
--

-- Dumped from database version 14.15 (Homebrew)
-- Dumped by pg_dump version 17.0

-- Started on 2026-08-22 19:48:53 AST

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
-- TOC entry 8 (class 2615 OID 337592)
-- Name: educa; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA educa;


ALTER SCHEMA educa OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 284 (class 1259 OID 338010)
-- Name: app_inventory; Type: TABLE; Schema: educa; Owner: postgres
--

CREATE TABLE educa.app_inventory (
    id bigint NOT NULL,
    prev_quantity integer DEFAULT 0,
    quantity integer,
    next_quantity integer DEFAULT 0,
    status character varying(10) DEFAULT 'quiet'::character varying,
    last_update timestamp(0) without time zone,
    user_updated character varying(90),
    product_id bigint,
    store_id bigint
);


ALTER TABLE educa.app_inventory OWNER TO postgres;

--
-- TOC entry 286 (class 1259 OID 338032)
-- Name: app_inventory_head; Type: TABLE; Schema: educa; Owner: postgres
--

CREATE TABLE educa.app_inventory_head (
    id bigint NOT NULL,
    name character varying(90),
    date_create timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    date_close timestamp(0) without time zone,
    status integer DEFAULT 0,
    memo character varying(500),
    store_id bigint
);


ALTER TABLE educa.app_inventory_head OWNER TO postgres;

--
-- TOC entry 285 (class 1259 OID 338031)
-- Name: app_inventory_head_id_seq; Type: SEQUENCE; Schema: educa; Owner: postgres
--

CREATE SEQUENCE educa.app_inventory_head_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE educa.app_inventory_head_id_seq OWNER TO postgres;

--
-- TOC entry 4042 (class 0 OID 0)
-- Dependencies: 285
-- Name: app_inventory_head_id_seq; Type: SEQUENCE OWNED BY; Schema: educa; Owner: postgres
--

ALTER SEQUENCE educa.app_inventory_head_id_seq OWNED BY educa.app_inventory_head.id;


--
-- TOC entry 283 (class 1259 OID 338009)
-- Name: app_inventory_id_seq; Type: SEQUENCE; Schema: educa; Owner: postgres
--

CREATE SEQUENCE educa.app_inventory_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE educa.app_inventory_id_seq OWNER TO postgres;

--
-- TOC entry 4043 (class 0 OID 0)
-- Dependencies: 283
-- Name: app_inventory_id_seq; Type: SEQUENCE OWNED BY; Schema: educa; Owner: postgres
--

ALTER SEQUENCE educa.app_inventory_id_seq OWNED BY educa.app_inventory.id;


--
-- TOC entry 270 (class 1259 OID 337946)
-- Name: app_sequence; Type: TABLE; Schema: educa; Owner: postgres
--

CREATE TABLE educa.app_sequence (
    id bigint NOT NULL,
    name character varying(255),
    code character varying(10),
    prefix character varying(10),
    fill integer,
    increment_by integer,
    current_seq bigint
);


ALTER TABLE educa.app_sequence OWNER TO postgres;

--
-- TOC entry 269 (class 1259 OID 337945)
-- Name: app_sequence_id_seq; Type: SEQUENCE; Schema: educa; Owner: postgres
--

CREATE SEQUENCE educa.app_sequence_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE educa.app_sequence_id_seq OWNER TO postgres;

--
-- TOC entry 4044 (class 0 OID 0)
-- Dependencies: 269
-- Name: app_sequence_id_seq; Type: SEQUENCE OWNED BY; Schema: educa; Owner: postgres
--

ALTER SEQUENCE educa.app_sequence_id_seq OWNED BY educa.app_sequence.id;


--
-- TOC entry 265 (class 1259 OID 337909)
-- Name: app_store; Type: TABLE; Schema: educa; Owner: postgres
--

CREATE TABLE educa.app_store (
    id bigint NOT NULL,
    name character varying(50),
    date_create timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    company_id character varying(50),
    slogan character varying(150),
    logo text,
    address character varying(200)
);


ALTER TABLE educa.app_store OWNER TO postgres;

--
-- TOC entry 264 (class 1259 OID 337908)
-- Name: app_store_id_seq; Type: SEQUENCE; Schema: educa; Owner: postgres
--

CREATE SEQUENCE educa.app_store_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE educa.app_store_id_seq OWNER TO postgres;

--
-- TOC entry 4045 (class 0 OID 0)
-- Dependencies: 264
-- Name: app_store_id_seq; Type: SEQUENCE OWNED BY; Schema: educa; Owner: postgres
--

ALTER SEQUENCE educa.app_store_id_seq OWNED BY educa.app_store.id;


--
-- TOC entry 268 (class 1259 OID 337929)
-- Name: app_user_store; Type: TABLE; Schema: educa; Owner: postgres
--

CREATE TABLE educa.app_user_store (
    user_id bigint NOT NULL,
    store_id bigint NOT NULL
);


ALTER TABLE educa.app_user_store OWNER TO postgres;

--
-- TOC entry 267 (class 1259 OID 337920)
-- Name: app_users; Type: TABLE; Schema: educa; Owner: postgres
--

CREATE TABLE educa.app_users (
    id bigint NOT NULL,
    username character varying(20),
    password character varying(200),
    first_name character varying(20),
    last_name character varying(30),
    is_active integer,
    date_joined timestamp(0) without time zone,
    last_login timestamp(0) without time zone,
    pic text
);


ALTER TABLE educa.app_users OWNER TO postgres;

--
-- TOC entry 266 (class 1259 OID 337919)
-- Name: app_users_id_seq; Type: SEQUENCE; Schema: educa; Owner: postgres
--

CREATE SEQUENCE educa.app_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE educa.app_users_id_seq OWNER TO postgres;

--
-- TOC entry 4046 (class 0 OID 0)
-- Dependencies: 266
-- Name: app_users_id_seq; Type: SEQUENCE OWNED BY; Schema: educa; Owner: postgres
--

ALTER SEQUENCE educa.app_users_id_seq OWNED BY educa.app_users.id;


--
-- TOC entry 272 (class 1259 OID 337953)
-- Name: bulk_order; Type: TABLE; Schema: educa; Owner: postgres
--

CREATE TABLE educa.bulk_order (
    id bigint NOT NULL,
    name character varying(45),
    memo character varying(500),
    date_create timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    user_create character varying(45)
);


ALTER TABLE educa.bulk_order OWNER TO postgres;

--
-- TOC entry 271 (class 1259 OID 337952)
-- Name: bulk_order_id_seq; Type: SEQUENCE; Schema: educa; Owner: postgres
--

CREATE SEQUENCE educa.bulk_order_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE educa.bulk_order_id_seq OWNER TO postgres;

--
-- TOC entry 4047 (class 0 OID 0)
-- Dependencies: 271
-- Name: bulk_order_id_seq; Type: SEQUENCE OWNED BY; Schema: educa; Owner: postgres
--

ALTER SEQUENCE educa.bulk_order_id_seq OWNED BY educa.bulk_order.id;


--
-- TOC entry 294 (class 1259 OID 338115)
-- Name: bulk_order_line; Type: TABLE; Schema: educa; Owner: postgres
--

CREATE TABLE educa.bulk_order_line (
    id bigint NOT NULL,
    bulk_order_id bigint,
    product_order_id bigint
);


ALTER TABLE educa.bulk_order_line OWNER TO postgres;

--
-- TOC entry 293 (class 1259 OID 338114)
-- Name: bulk_order_line_id_seq; Type: SEQUENCE; Schema: educa; Owner: postgres
--

CREATE SEQUENCE educa.bulk_order_line_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE educa.bulk_order_line_id_seq OWNER TO postgres;

--
-- TOC entry 4048 (class 0 OID 0)
-- Dependencies: 293
-- Name: bulk_order_line_id_seq; Type: SEQUENCE OWNED BY; Schema: educa; Owner: postgres
--

ALTER SEQUENCE educa.bulk_order_line_id_seq OWNED BY educa.bulk_order_line.id;


--
-- TOC entry 274 (class 1259 OID 337963)
-- Name: client; Type: TABLE; Schema: educa; Owner: postgres
--

CREATE TABLE educa.client (
    id bigint NOT NULL,
    name character varying(255),
    document_id character varying(30),
    address character varying(255),
    celphone character varying(100),
    email character varying(100),
    date_create timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    wholesaler integer
);


ALTER TABLE educa.client OWNER TO postgres;

--
-- TOC entry 273 (class 1259 OID 337962)
-- Name: client_id_seq; Type: SEQUENCE; Schema: educa; Owner: postgres
--

CREATE SEQUENCE educa.client_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE educa.client_id_seq OWNER TO postgres;

--
-- TOC entry 4049 (class 0 OID 0)
-- Dependencies: 273
-- Name: client_id_seq; Type: SEQUENCE OWNED BY; Schema: educa; Owner: postgres
--

ALTER SEQUENCE educa.client_id_seq OWNED BY educa.client.id;


--
-- TOC entry 219 (class 1259 OID 337598)
-- Name: company; Type: TABLE; Schema: educa; Owner: postgres
--

CREATE TABLE educa.company (
    id uuid NOT NULL,
    rnc character varying(255),
    company_name character varying(255),
    access_token text,
    active boolean DEFAULT true NOT NULL,
    connected boolean DEFAULT false NOT NULL,
    odoo_url character varying(255),
    odoo_db character varying(255),
    odoo_user character varying(255),
    odoo_apikey character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


ALTER TABLE educa.company OWNER TO postgres;

--
-- TOC entry 276 (class 1259 OID 337973)
-- Name: delivery; Type: TABLE; Schema: educa; Owner: postgres
--

CREATE TABLE educa.delivery (
    id bigint NOT NULL,
    name character varying(45),
    value double precision
);


ALTER TABLE educa.delivery OWNER TO postgres;

--
-- TOC entry 275 (class 1259 OID 337972)
-- Name: delivery_id_seq; Type: SEQUENCE; Schema: educa; Owner: postgres
--

CREATE SEQUENCE educa.delivery_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE educa.delivery_id_seq OWNER TO postgres;

--
-- TOC entry 4050 (class 0 OID 0)
-- Dependencies: 275
-- Name: delivery_id_seq; Type: SEQUENCE OWNED BY; Schema: educa; Owner: postgres
--

ALTER SEQUENCE educa.delivery_id_seq OWNED BY educa.delivery.id;


--
-- TOC entry 278 (class 1259 OID 337980)
-- Name: pricing; Type: TABLE; Schema: educa; Owner: postgres
--

CREATE TABLE educa.pricing (
    id bigint NOT NULL,
    label character varying(90) NOT NULL,
    user_modified character varying(90),
    date_create timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    price_key character varying(45) NOT NULL,
    status integer DEFAULT 1
);


ALTER TABLE educa.pricing OWNER TO postgres;

--
-- TOC entry 277 (class 1259 OID 337979)
-- Name: pricing_id_seq; Type: SEQUENCE; Schema: educa; Owner: postgres
--

CREATE SEQUENCE educa.pricing_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE educa.pricing_id_seq OWNER TO postgres;

--
-- TOC entry 4051 (class 0 OID 0)
-- Dependencies: 277
-- Name: pricing_id_seq; Type: SEQUENCE OWNED BY; Schema: educa; Owner: postgres
--

ALTER SEQUENCE educa.pricing_id_seq OWNED BY educa.pricing.id;


--
-- TOC entry 288 (class 1259 OID 338049)
-- Name: pricing_list; Type: TABLE; Schema: educa; Owner: postgres
--

CREATE TABLE educa.pricing_list (
    id bigint NOT NULL,
    price double precision,
    user_modified character varying(90),
    date_create timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    product_id bigint,
    pricing_id bigint
);


ALTER TABLE educa.pricing_list OWNER TO postgres;

--
-- TOC entry 287 (class 1259 OID 338048)
-- Name: pricing_list_id_seq; Type: SEQUENCE; Schema: educa; Owner: postgres
--

CREATE SEQUENCE educa.pricing_list_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE educa.pricing_list_id_seq OWNER TO postgres;

--
-- TOC entry 4052 (class 0 OID 0)
-- Dependencies: 287
-- Name: pricing_list_id_seq; Type: SEQUENCE OWNED BY; Schema: educa; Owner: postgres
--

ALTER SEQUENCE educa.pricing_list_id_seq OWNED BY educa.pricing_list.id;


--
-- TOC entry 280 (class 1259 OID 337991)
-- Name: product; Type: TABLE; Schema: educa; Owner: postgres
--

CREATE TABLE educa.product (
    id bigint NOT NULL,
    name character varying(255),
    cost double precision,
    price double precision,
    margin double precision,
    code character varying(45),
    img_path character varying(255),
    date_create timestamp(0) without time zone,
    image_raw text,
    active integer,
    user_modified character varying(45),
    archived character varying(1) DEFAULT '0'::character varying
);


ALTER TABLE educa.product OWNER TO postgres;

--
-- TOC entry 282 (class 1259 OID 338001)
-- Name: product_bck; Type: TABLE; Schema: educa; Owner: postgres
--

CREATE TABLE educa.product_bck (
    id bigint NOT NULL,
    name character varying(255),
    cost double precision,
    price double precision,
    margin double precision,
    code character varying(45),
    img_path character varying(255),
    date_create timestamp(0) without time zone,
    image_raw text,
    active integer,
    user_modified character varying(45)
);


ALTER TABLE educa.product_bck OWNER TO postgres;

--
-- TOC entry 281 (class 1259 OID 338000)
-- Name: product_bck_id_seq; Type: SEQUENCE; Schema: educa; Owner: postgres
--

CREATE SEQUENCE educa.product_bck_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE educa.product_bck_id_seq OWNER TO postgres;

--
-- TOC entry 4053 (class 0 OID 0)
-- Dependencies: 281
-- Name: product_bck_id_seq; Type: SEQUENCE OWNED BY; Schema: educa; Owner: postgres
--

ALTER SEQUENCE educa.product_bck_id_seq OWNED BY educa.product_bck.id;


--
-- TOC entry 279 (class 1259 OID 337990)
-- Name: product_id_seq; Type: SEQUENCE; Schema: educa; Owner: postgres
--

CREATE SEQUENCE educa.product_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE educa.product_id_seq OWNER TO postgres;

--
-- TOC entry 4054 (class 0 OID 0)
-- Dependencies: 279
-- Name: product_id_seq; Type: SEQUENCE OWNED BY; Schema: educa; Owner: postgres
--

ALTER SEQUENCE educa.product_id_seq OWNED BY educa.product.id;


--
-- TOC entry 290 (class 1259 OID 338069)
-- Name: product_order; Type: TABLE; Schema: educa; Owner: postgres
--

CREATE TABLE educa.product_order (
    id bigint NOT NULL,
    name character varying(90),
    memo character varying(500),
    order_type character varying(45),
    user_requester character varying(45),
    user_receiver character varying(45),
    date_opened timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    date_closed timestamp(0) without time zone,
    from_origin_id integer,
    to_store_id bigint,
    status character varying(45) DEFAULT 'opened'::character varying
);


ALTER TABLE educa.product_order OWNER TO postgres;

--
-- TOC entry 289 (class 1259 OID 338068)
-- Name: product_order_id_seq; Type: SEQUENCE; Schema: educa; Owner: postgres
--

CREATE SEQUENCE educa.product_order_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE educa.product_order_id_seq OWNER TO postgres;

--
-- TOC entry 4055 (class 0 OID 0)
-- Dependencies: 289
-- Name: product_order_id_seq; Type: SEQUENCE OWNED BY; Schema: educa; Owner: postgres
--

ALTER SEQUENCE educa.product_order_id_seq OWNED BY educa.product_order.id;


--
-- TOC entry 292 (class 1259 OID 338086)
-- Name: product_order_line; Type: TABLE; Schema: educa; Owner: postgres
--

CREATE TABLE educa.product_order_line (
    id bigint NOT NULL,
    product_id bigint,
    from_origin_id integer,
    to_store_id bigint,
    product_order_id bigint,
    quantity integer,
    quantity_observed integer,
    status character varying(10) DEFAULT 'pending'::character varying,
    date_create timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    user_receiver character varying(45),
    receiver_last_update timestamp(0) without time zone,
    receiver_memo character varying(500)
);


ALTER TABLE educa.product_order_line OWNER TO postgres;

--
-- TOC entry 291 (class 1259 OID 338085)
-- Name: product_order_line_id_seq; Type: SEQUENCE; Schema: educa; Owner: postgres
--

CREATE SEQUENCE educa.product_order_line_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE educa.product_order_line_id_seq OWNER TO postgres;

--
-- TOC entry 4056 (class 0 OID 0)
-- Dependencies: 291
-- Name: product_order_line_id_seq; Type: SEQUENCE OWNED BY; Schema: educa; Owner: postgres
--

ALTER SEQUENCE educa.product_order_line_id_seq OWNED BY educa.product_order_line.id;


--
-- TOC entry 296 (class 1259 OID 338134)
-- Name: provider; Type: TABLE; Schema: educa; Owner: postgres
--

CREATE TABLE educa.provider (
    id bigint NOT NULL,
    name character varying(50),
    date_create timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE educa.provider OWNER TO postgres;

--
-- TOC entry 295 (class 1259 OID 338133)
-- Name: provider_id_seq; Type: SEQUENCE; Schema: educa; Owner: postgres
--

CREATE SEQUENCE educa.provider_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE educa.provider_id_seq OWNER TO postgres;

--
-- TOC entry 4057 (class 0 OID 0)
-- Dependencies: 295
-- Name: provider_id_seq; Type: SEQUENCE OWNED BY; Schema: educa; Owner: postgres
--

ALTER SEQUENCE educa.provider_id_seq OWNED BY educa.provider.id;


--
-- TOC entry 298 (class 1259 OID 338143)
-- Name: sale; Type: TABLE; Schema: educa; Owner: postgres
--

CREATE TABLE educa.sale (
    id bigint NOT NULL,
    amount double precision,
    sub double precision,
    discount double precision,
    tax_amount double precision,
    delivery_charge double precision,
    sequence character varying(30),
    sequence_type character varying(45),
    status character varying(45),
    sale_type character varying(45),
    date_create timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    login character varying(45),
    client_id bigint DEFAULT 0 NOT NULL,
    store_id bigint DEFAULT 0 NOT NULL,
    additional_info character varying(1000)
);


ALTER TABLE educa.sale OWNER TO postgres;

--
-- TOC entry 297 (class 1259 OID 338142)
-- Name: sale_id_seq; Type: SEQUENCE; Schema: educa; Owner: postgres
--

CREATE SEQUENCE educa.sale_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE educa.sale_id_seq OWNER TO postgres;

--
-- TOC entry 4058 (class 0 OID 0)
-- Dependencies: 297
-- Name: sale_id_seq; Type: SEQUENCE OWNED BY; Schema: educa; Owner: postgres
--

ALTER SEQUENCE educa.sale_id_seq OWNED BY educa.sale.id;


--
-- TOC entry 300 (class 1259 OID 338157)
-- Name: sale_line; Type: TABLE; Schema: educa; Owner: postgres
--

CREATE TABLE educa.sale_line (
    id bigint NOT NULL,
    amount double precision,
    tax_amount double precision,
    discount double precision,
    quantity double precision,
    total_amount double precision,
    sale_id bigint DEFAULT 0 NOT NULL,
    product_id bigint
);


ALTER TABLE educa.sale_line OWNER TO postgres;

--
-- TOC entry 299 (class 1259 OID 338156)
-- Name: sale_line_id_seq; Type: SEQUENCE; Schema: educa; Owner: postgres
--

CREATE SEQUENCE educa.sale_line_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE educa.sale_line_id_seq OWNER TO postgres;

--
-- TOC entry 4059 (class 0 OID 0)
-- Dependencies: 299
-- Name: sale_line_id_seq; Type: SEQUENCE OWNED BY; Schema: educa; Owner: postgres
--

ALTER SEQUENCE educa.sale_line_id_seq OWNED BY educa.sale_line.id;


--
-- TOC entry 302 (class 1259 OID 338165)
-- Name: sale_paid; Type: TABLE; Schema: educa; Owner: postgres
--

CREATE TABLE educa.sale_paid (
    id bigint NOT NULL,
    amount double precision,
    type character varying(10),
    date_create timestamp(0) without time zone,
    sale_id bigint DEFAULT 0 NOT NULL
);


ALTER TABLE educa.sale_paid OWNER TO postgres;

--
-- TOC entry 301 (class 1259 OID 338164)
-- Name: sale_paid_id_seq; Type: SEQUENCE; Schema: educa; Owner: postgres
--

CREATE SEQUENCE educa.sale_paid_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE educa.sale_paid_id_seq OWNER TO postgres;

--
-- TOC entry 4060 (class 0 OID 0)
-- Dependencies: 301
-- Name: sale_paid_id_seq; Type: SEQUENCE OWNED BY; Schema: educa; Owner: postgres
--

ALTER SEQUENCE educa.sale_paid_id_seq OWNED BY educa.sale_paid.id;


--
-- TOC entry 218 (class 1259 OID 337593)
-- Name: schema_migrations; Type: TABLE; Schema: educa; Owner: postgres
--

CREATE TABLE educa.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


ALTER TABLE educa.schema_migrations OWNER TO postgres;

--
-- TOC entry 304 (class 1259 OID 338173)
-- Name: scope_list; Type: TABLE; Schema: educa; Owner: postgres
--

CREATE TABLE educa.scope_list (
    id bigint NOT NULL,
    name character varying(200)
);


ALTER TABLE educa.scope_list OWNER TO postgres;

--
-- TOC entry 303 (class 1259 OID 338172)
-- Name: scope_list_id_seq; Type: SEQUENCE; Schema: educa; Owner: postgres
--

CREATE SEQUENCE educa.scope_list_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE educa.scope_list_id_seq OWNER TO postgres;

--
-- TOC entry 4061 (class 0 OID 0)
-- Dependencies: 303
-- Name: scope_list_id_seq; Type: SEQUENCE OWNED BY; Schema: educa; Owner: postgres
--

ALTER SEQUENCE educa.scope_list_id_seq OWNED BY educa.scope_list.id;


--
-- TOC entry 306 (class 1259 OID 338180)
-- Name: scopes; Type: TABLE; Schema: educa; Owner: postgres
--

CREATE TABLE educa.scopes (
    id bigint NOT NULL,
    name character varying(50),
    user_id bigint
);


ALTER TABLE educa.scopes OWNER TO postgres;

--
-- TOC entry 305 (class 1259 OID 338179)
-- Name: scopes_id_seq; Type: SEQUENCE; Schema: educa; Owner: postgres
--

CREATE SEQUENCE educa.scopes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE educa.scopes_id_seq OWNER TO postgres;

--
-- TOC entry 4062 (class 0 OID 0)
-- Dependencies: 305
-- Name: scopes_id_seq; Type: SEQUENCE OWNED BY; Schema: educa; Owner: postgres
--

ALTER SEQUENCE educa.scopes_id_seq OWNED BY educa.scopes.id;


--
-- TOC entry 220 (class 1259 OID 337610)
-- Name: users_companies; Type: TABLE; Schema: educa; Owner: postgres
--

CREATE TABLE educa.users_companies (
    user_id uuid,
    company_id uuid
);


ALTER TABLE educa.users_companies OWNER TO postgres;

--
-- TOC entry 3782 (class 2604 OID 338013)
-- Name: app_inventory id; Type: DEFAULT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.app_inventory ALTER COLUMN id SET DEFAULT nextval('educa.app_inventory_id_seq'::regclass);


--
-- TOC entry 3786 (class 2604 OID 338035)
-- Name: app_inventory_head id; Type: DEFAULT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.app_inventory_head ALTER COLUMN id SET DEFAULT nextval('educa.app_inventory_head_id_seq'::regclass);


--
-- TOC entry 3770 (class 2604 OID 337949)
-- Name: app_sequence id; Type: DEFAULT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.app_sequence ALTER COLUMN id SET DEFAULT nextval('educa.app_sequence_id_seq'::regclass);


--
-- TOC entry 3767 (class 2604 OID 337912)
-- Name: app_store id; Type: DEFAULT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.app_store ALTER COLUMN id SET DEFAULT nextval('educa.app_store_id_seq'::regclass);


--
-- TOC entry 3769 (class 2604 OID 337923)
-- Name: app_users id; Type: DEFAULT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.app_users ALTER COLUMN id SET DEFAULT nextval('educa.app_users_id_seq'::regclass);


--
-- TOC entry 3771 (class 2604 OID 337956)
-- Name: bulk_order id; Type: DEFAULT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.bulk_order ALTER COLUMN id SET DEFAULT nextval('educa.bulk_order_id_seq'::regclass);


--
-- TOC entry 3797 (class 2604 OID 338118)
-- Name: bulk_order_line id; Type: DEFAULT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.bulk_order_line ALTER COLUMN id SET DEFAULT nextval('educa.bulk_order_line_id_seq'::regclass);


--
-- TOC entry 3773 (class 2604 OID 337966)
-- Name: client id; Type: DEFAULT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.client ALTER COLUMN id SET DEFAULT nextval('educa.client_id_seq'::regclass);


--
-- TOC entry 3775 (class 2604 OID 337976)
-- Name: delivery id; Type: DEFAULT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.delivery ALTER COLUMN id SET DEFAULT nextval('educa.delivery_id_seq'::regclass);


--
-- TOC entry 3776 (class 2604 OID 337983)
-- Name: pricing id; Type: DEFAULT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.pricing ALTER COLUMN id SET DEFAULT nextval('educa.pricing_id_seq'::regclass);


--
-- TOC entry 3789 (class 2604 OID 338052)
-- Name: pricing_list id; Type: DEFAULT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.pricing_list ALTER COLUMN id SET DEFAULT nextval('educa.pricing_list_id_seq'::regclass);


--
-- TOC entry 3779 (class 2604 OID 337994)
-- Name: product id; Type: DEFAULT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.product ALTER COLUMN id SET DEFAULT nextval('educa.product_id_seq'::regclass);


--
-- TOC entry 3781 (class 2604 OID 338004)
-- Name: product_bck id; Type: DEFAULT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.product_bck ALTER COLUMN id SET DEFAULT nextval('educa.product_bck_id_seq'::regclass);


--
-- TOC entry 3791 (class 2604 OID 338072)
-- Name: product_order id; Type: DEFAULT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.product_order ALTER COLUMN id SET DEFAULT nextval('educa.product_order_id_seq'::regclass);


--
-- TOC entry 3794 (class 2604 OID 338089)
-- Name: product_order_line id; Type: DEFAULT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.product_order_line ALTER COLUMN id SET DEFAULT nextval('educa.product_order_line_id_seq'::regclass);


--
-- TOC entry 3798 (class 2604 OID 338137)
-- Name: provider id; Type: DEFAULT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.provider ALTER COLUMN id SET DEFAULT nextval('educa.provider_id_seq'::regclass);


--
-- TOC entry 3800 (class 2604 OID 338146)
-- Name: sale id; Type: DEFAULT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.sale ALTER COLUMN id SET DEFAULT nextval('educa.sale_id_seq'::regclass);


--
-- TOC entry 3804 (class 2604 OID 338160)
-- Name: sale_line id; Type: DEFAULT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.sale_line ALTER COLUMN id SET DEFAULT nextval('educa.sale_line_id_seq'::regclass);


--
-- TOC entry 3806 (class 2604 OID 338168)
-- Name: sale_paid id; Type: DEFAULT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.sale_paid ALTER COLUMN id SET DEFAULT nextval('educa.sale_paid_id_seq'::regclass);


--
-- TOC entry 3808 (class 2604 OID 338176)
-- Name: scope_list id; Type: DEFAULT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.scope_list ALTER COLUMN id SET DEFAULT nextval('educa.scope_list_id_seq'::regclass);


--
-- TOC entry 3809 (class 2604 OID 338183)
-- Name: scopes id; Type: DEFAULT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.scopes ALTER COLUMN id SET DEFAULT nextval('educa.scopes_id_seq'::regclass);


--
-- TOC entry 3848 (class 2606 OID 338041)
-- Name: app_inventory_head app_inventory_head_pkey; Type: CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.app_inventory_head
    ADD CONSTRAINT app_inventory_head_pkey PRIMARY KEY (id);


--
-- TOC entry 3844 (class 2606 OID 338018)
-- Name: app_inventory app_inventory_pkey; Type: CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.app_inventory
    ADD CONSTRAINT app_inventory_pkey PRIMARY KEY (id);


--
-- TOC entry 3828 (class 2606 OID 337951)
-- Name: app_sequence app_sequence_pkey; Type: CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.app_sequence
    ADD CONSTRAINT app_sequence_pkey PRIMARY KEY (id);


--
-- TOC entry 3820 (class 2606 OID 337917)
-- Name: app_store app_store_pkey; Type: CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.app_store
    ADD CONSTRAINT app_store_pkey PRIMARY KEY (id);


--
-- TOC entry 3825 (class 2606 OID 337933)
-- Name: app_user_store app_user_store_pkey; Type: CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.app_user_store
    ADD CONSTRAINT app_user_store_pkey PRIMARY KEY (user_id, store_id);


--
-- TOC entry 3822 (class 2606 OID 337927)
-- Name: app_users app_users_pkey; Type: CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.app_users
    ADD CONSTRAINT app_users_pkey PRIMARY KEY (id);


--
-- TOC entry 3864 (class 2606 OID 338120)
-- Name: bulk_order_line bulk_order_line_pkey; Type: CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.bulk_order_line
    ADD CONSTRAINT bulk_order_line_pkey PRIMARY KEY (id);


--
-- TOC entry 3830 (class 2606 OID 337961)
-- Name: bulk_order bulk_order_pkey; Type: CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.bulk_order
    ADD CONSTRAINT bulk_order_pkey PRIMARY KEY (id);


--
-- TOC entry 3832 (class 2606 OID 337971)
-- Name: client client_pkey; Type: CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.client
    ADD CONSTRAINT client_pkey PRIMARY KEY (id);


--
-- TOC entry 3815 (class 2606 OID 337606)
-- Name: company company_pkey; Type: CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.company
    ADD CONSTRAINT company_pkey PRIMARY KEY (id);


--
-- TOC entry 3834 (class 2606 OID 337978)
-- Name: delivery delivery_pkey; Type: CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.delivery
    ADD CONSTRAINT delivery_pkey PRIMARY KEY (id);


--
-- TOC entry 3851 (class 2606 OID 338055)
-- Name: pricing_list pricing_list_pkey; Type: CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.pricing_list
    ADD CONSTRAINT pricing_list_pkey PRIMARY KEY (id);


--
-- TOC entry 3837 (class 2606 OID 337987)
-- Name: pricing pricing_pkey; Type: CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.pricing
    ADD CONSTRAINT pricing_pkey PRIMARY KEY (id);


--
-- TOC entry 3842 (class 2606 OID 338008)
-- Name: product_bck product_bck_pkey; Type: CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.product_bck
    ADD CONSTRAINT product_bck_pkey PRIMARY KEY (id);


--
-- TOC entry 3858 (class 2606 OID 338095)
-- Name: product_order_line product_order_line_pkey; Type: CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.product_order_line
    ADD CONSTRAINT product_order_line_pkey PRIMARY KEY (id);


--
-- TOC entry 3855 (class 2606 OID 338078)
-- Name: product_order product_order_pkey; Type: CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.product_order
    ADD CONSTRAINT product_order_pkey PRIMARY KEY (id);


--
-- TOC entry 3840 (class 2606 OID 337999)
-- Name: product product_pkey; Type: CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.product
    ADD CONSTRAINT product_pkey PRIMARY KEY (id);


--
-- TOC entry 3868 (class 2606 OID 338140)
-- Name: provider provider_pkey; Type: CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.provider
    ADD CONSTRAINT provider_pkey PRIMARY KEY (id);


--
-- TOC entry 3874 (class 2606 OID 338163)
-- Name: sale_line sale_line_pkey; Type: CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.sale_line
    ADD CONSTRAINT sale_line_pkey PRIMARY KEY (id);


--
-- TOC entry 3876 (class 2606 OID 338171)
-- Name: sale_paid sale_paid_pkey; Type: CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.sale_paid
    ADD CONSTRAINT sale_paid_pkey PRIMARY KEY (id);


--
-- TOC entry 3870 (class 2606 OID 338153)
-- Name: sale sale_pkey; Type: CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.sale
    ADD CONSTRAINT sale_pkey PRIMARY KEY (id);


--
-- TOC entry 3811 (class 2606 OID 337597)
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- TOC entry 3878 (class 2606 OID 338178)
-- Name: scope_list scope_list_pkey; Type: CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.scope_list
    ADD CONSTRAINT scope_list_pkey PRIMARY KEY (id);


--
-- TOC entry 3880 (class 2606 OID 338185)
-- Name: scopes scopes_pkey; Type: CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.scopes
    ADD CONSTRAINT scopes_pkey PRIMARY KEY (id);


--
-- TOC entry 3849 (class 1259 OID 338047)
-- Name: app_inventory_head_store_id_index; Type: INDEX; Schema: educa; Owner: postgres
--

CREATE INDEX app_inventory_head_store_id_index ON educa.app_inventory_head USING btree (store_id);


--
-- TOC entry 3845 (class 1259 OID 338029)
-- Name: app_inventory_product_id_index; Type: INDEX; Schema: educa; Owner: postgres
--

CREATE INDEX app_inventory_product_id_index ON educa.app_inventory USING btree (product_id);


--
-- TOC entry 3846 (class 1259 OID 338030)
-- Name: app_inventory_store_id_index; Type: INDEX; Schema: educa; Owner: postgres
--

CREATE INDEX app_inventory_store_id_index ON educa.app_inventory USING btree (store_id);


--
-- TOC entry 3818 (class 1259 OID 337918)
-- Name: app_store_name_index; Type: INDEX; Schema: educa; Owner: postgres
--

CREATE UNIQUE INDEX app_store_name_index ON educa.app_store USING btree (name);


--
-- TOC entry 3826 (class 1259 OID 337944)
-- Name: app_user_store_store_id_index; Type: INDEX; Schema: educa; Owner: postgres
--

CREATE INDEX app_user_store_store_id_index ON educa.app_user_store USING btree (store_id);


--
-- TOC entry 3823 (class 1259 OID 337928)
-- Name: app_users_username_index; Type: INDEX; Schema: educa; Owner: postgres
--

CREATE UNIQUE INDEX app_users_username_index ON educa.app_users USING btree (username);


--
-- TOC entry 3862 (class 1259 OID 338131)
-- Name: bulk_order_line_bulk_order_id_index; Type: INDEX; Schema: educa; Owner: postgres
--

CREATE INDEX bulk_order_line_bulk_order_id_index ON educa.bulk_order_line USING btree (bulk_order_id);


--
-- TOC entry 3865 (class 1259 OID 338132)
-- Name: bulk_order_line_product_order_id_index; Type: INDEX; Schema: educa; Owner: postgres
--

CREATE INDEX bulk_order_line_product_order_id_index ON educa.bulk_order_line USING btree (product_order_id);


--
-- TOC entry 3812 (class 1259 OID 337609)
-- Name: company_access_token_index; Type: INDEX; Schema: educa; Owner: postgres
--

CREATE INDEX company_access_token_index ON educa.company USING btree (access_token);


--
-- TOC entry 3813 (class 1259 OID 337608)
-- Name: company_company_name_index; Type: INDEX; Schema: educa; Owner: postgres
--

CREATE INDEX company_company_name_index ON educa.company USING btree (company_name);


--
-- TOC entry 3816 (class 1259 OID 337607)
-- Name: company_rnc_index; Type: INDEX; Schema: educa; Owner: postgres
--

CREATE INDEX company_rnc_index ON educa.company USING btree (rnc);


--
-- TOC entry 3835 (class 1259 OID 337988)
-- Name: pricing_label_index; Type: INDEX; Schema: educa; Owner: postgres
--

CREATE UNIQUE INDEX pricing_label_index ON educa.pricing USING btree (label);


--
-- TOC entry 3852 (class 1259 OID 338067)
-- Name: pricing_list_pricing_id_index; Type: INDEX; Schema: educa; Owner: postgres
--

CREATE INDEX pricing_list_pricing_id_index ON educa.pricing_list USING btree (pricing_id);


--
-- TOC entry 3853 (class 1259 OID 338066)
-- Name: pricing_list_product_id_index; Type: INDEX; Schema: educa; Owner: postgres
--

CREATE INDEX pricing_list_product_id_index ON educa.pricing_list USING btree (product_id);


--
-- TOC entry 3838 (class 1259 OID 337989)
-- Name: pricing_price_key_index; Type: INDEX; Schema: educa; Owner: postgres
--

CREATE UNIQUE INDEX pricing_price_key_index ON educa.pricing USING btree (price_key);


--
-- TOC entry 3859 (class 1259 OID 338111)
-- Name: product_order_line_product_id_index; Type: INDEX; Schema: educa; Owner: postgres
--

CREATE INDEX product_order_line_product_id_index ON educa.product_order_line USING btree (product_id);


--
-- TOC entry 3860 (class 1259 OID 338113)
-- Name: product_order_line_product_order_id_index; Type: INDEX; Schema: educa; Owner: postgres
--

CREATE INDEX product_order_line_product_order_id_index ON educa.product_order_line USING btree (product_order_id);


--
-- TOC entry 3861 (class 1259 OID 338112)
-- Name: product_order_line_to_store_id_index; Type: INDEX; Schema: educa; Owner: postgres
--

CREATE INDEX product_order_line_to_store_id_index ON educa.product_order_line USING btree (to_store_id);


--
-- TOC entry 3856 (class 1259 OID 338084)
-- Name: product_order_to_store_id_index; Type: INDEX; Schema: educa; Owner: postgres
--

CREATE INDEX product_order_to_store_id_index ON educa.product_order USING btree (to_store_id);


--
-- TOC entry 3866 (class 1259 OID 338141)
-- Name: provider_name_index; Type: INDEX; Schema: educa; Owner: postgres
--

CREATE UNIQUE INDEX provider_name_index ON educa.provider USING btree (name);


--
-- TOC entry 3871 (class 1259 OID 338155)
-- Name: sale_store_id_client_id_date_create_index; Type: INDEX; Schema: educa; Owner: postgres
--

CREATE INDEX sale_store_id_client_id_date_create_index ON educa.sale USING btree (store_id, client_id, date_create);


--
-- TOC entry 3872 (class 1259 OID 338154)
-- Name: sale_store_id_date_create_index; Type: INDEX; Schema: educa; Owner: postgres
--

CREATE INDEX sale_store_id_date_create_index ON educa.sale USING btree (store_id, date_create);


--
-- TOC entry 3881 (class 1259 OID 338191)
-- Name: scopes_user_id_index; Type: INDEX; Schema: educa; Owner: postgres
--

CREATE INDEX scopes_user_id_index ON educa.scopes USING btree (user_id);


--
-- TOC entry 3817 (class 1259 OID 337623)
-- Name: users_companies_user_id_company_id_index; Type: INDEX; Schema: educa; Owner: postgres
--

CREATE UNIQUE INDEX users_companies_user_id_company_id_index ON educa.users_companies USING btree (user_id, company_id);


--
-- TOC entry 3888 (class 2606 OID 338042)
-- Name: app_inventory_head app_inventory_head_store_id_fkey; Type: FK CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.app_inventory_head
    ADD CONSTRAINT app_inventory_head_store_id_fkey FOREIGN KEY (store_id) REFERENCES educa.app_store(id);


--
-- TOC entry 3886 (class 2606 OID 338019)
-- Name: app_inventory app_inventory_product_id_fkey; Type: FK CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.app_inventory
    ADD CONSTRAINT app_inventory_product_id_fkey FOREIGN KEY (product_id) REFERENCES educa.product(id);


--
-- TOC entry 3887 (class 2606 OID 338024)
-- Name: app_inventory app_inventory_store_id_fkey; Type: FK CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.app_inventory
    ADD CONSTRAINT app_inventory_store_id_fkey FOREIGN KEY (store_id) REFERENCES educa.app_store(id);


--
-- TOC entry 3884 (class 2606 OID 337939)
-- Name: app_user_store app_user_store_store_id_fkey; Type: FK CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.app_user_store
    ADD CONSTRAINT app_user_store_store_id_fkey FOREIGN KEY (store_id) REFERENCES educa.app_store(id);


--
-- TOC entry 3885 (class 2606 OID 337934)
-- Name: app_user_store app_user_store_user_id_fkey; Type: FK CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.app_user_store
    ADD CONSTRAINT app_user_store_user_id_fkey FOREIGN KEY (user_id) REFERENCES educa.app_users(id);


--
-- TOC entry 3895 (class 2606 OID 338121)
-- Name: bulk_order_line bulk_order_line_bulk_order_id_fkey; Type: FK CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.bulk_order_line
    ADD CONSTRAINT bulk_order_line_bulk_order_id_fkey FOREIGN KEY (bulk_order_id) REFERENCES educa.bulk_order(id);


--
-- TOC entry 3896 (class 2606 OID 338126)
-- Name: bulk_order_line bulk_order_line_product_order_id_fkey; Type: FK CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.bulk_order_line
    ADD CONSTRAINT bulk_order_line_product_order_id_fkey FOREIGN KEY (product_order_id) REFERENCES educa.product_order(id);


--
-- TOC entry 3889 (class 2606 OID 338061)
-- Name: pricing_list pricing_list_pricing_id_fkey; Type: FK CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.pricing_list
    ADD CONSTRAINT pricing_list_pricing_id_fkey FOREIGN KEY (pricing_id) REFERENCES educa.pricing(id);


--
-- TOC entry 3890 (class 2606 OID 338056)
-- Name: pricing_list pricing_list_product_id_fkey; Type: FK CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.pricing_list
    ADD CONSTRAINT pricing_list_product_id_fkey FOREIGN KEY (product_id) REFERENCES educa.product(id);


--
-- TOC entry 3892 (class 2606 OID 338096)
-- Name: product_order_line product_order_line_product_id_fkey; Type: FK CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.product_order_line
    ADD CONSTRAINT product_order_line_product_id_fkey FOREIGN KEY (product_id) REFERENCES educa.product(id);


--
-- TOC entry 3893 (class 2606 OID 338106)
-- Name: product_order_line product_order_line_product_order_id_fkey; Type: FK CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.product_order_line
    ADD CONSTRAINT product_order_line_product_order_id_fkey FOREIGN KEY (product_order_id) REFERENCES educa.product_order(id);


--
-- TOC entry 3894 (class 2606 OID 338101)
-- Name: product_order_line product_order_line_to_store_id_fkey; Type: FK CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.product_order_line
    ADD CONSTRAINT product_order_line_to_store_id_fkey FOREIGN KEY (to_store_id) REFERENCES educa.app_store(id);


--
-- TOC entry 3891 (class 2606 OID 338079)
-- Name: product_order product_order_to_store_id_fkey; Type: FK CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.product_order
    ADD CONSTRAINT product_order_to_store_id_fkey FOREIGN KEY (to_store_id) REFERENCES educa.app_store(id);


--
-- TOC entry 3897 (class 2606 OID 338186)
-- Name: scopes scopes_user_id_fkey; Type: FK CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.scopes
    ADD CONSTRAINT scopes_user_id_fkey FOREIGN KEY (user_id) REFERENCES educa.app_users(id);


--
-- TOC entry 3882 (class 2606 OID 337618)
-- Name: users_companies users_companies_company_id_fkey; Type: FK CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.users_companies
    ADD CONSTRAINT users_companies_company_id_fkey FOREIGN KEY (company_id) REFERENCES educa.company(id) ON DELETE CASCADE;


--
-- TOC entry 3883 (class 2606 OID 337613)
-- Name: users_companies users_companies_user_id_fkey; Type: FK CONSTRAINT; Schema: educa; Owner: postgres
--

ALTER TABLE ONLY educa.users_companies
    ADD CONSTRAINT users_companies_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


-- Completed on 2026-08-22 19:48:53 AST

--
-- PostgreSQL database dump complete
--

