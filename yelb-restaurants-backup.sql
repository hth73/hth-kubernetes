--
-- PostgreSQL database dump
--

\restrict c1JUuKGuWT0fZYFmigUI6JsaInpBtW0AqlUasXdurx8aRDxcWVC3KLtA3UhvG88

-- Dumped from database version 15.19 (Debian 15.19-1.pgdg13+2)
-- Dumped by pg_dump version 15.19 (Debian 15.19-1.pgdg13+2)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: restaurants; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.restaurants (
    name character(30) NOT NULL,
    count integer
);


ALTER TABLE public.restaurants OWNER TO postgres;

--
-- Data for Name: restaurants; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.restaurants (name, count) FROM stdin;
outback                       	0
bucadibeppo                   	0
chipotle                      	0
ihop                          	0
\.


--
-- Name: restaurants restaurants_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.restaurants
    ADD CONSTRAINT restaurants_pkey PRIMARY KEY (name);


--
-- PostgreSQL database dump complete
--

\unrestrict c1JUuKGuWT0fZYFmigUI6JsaInpBtW0AqlUasXdurx8aRDxcWVC3KLtA3UhvG88

