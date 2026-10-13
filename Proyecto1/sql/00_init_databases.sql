CREATE DATABASE sgfood_oltp;
CREATE DATABASE sgfood_dw;

\connect sgfood_oltp
\i /data/oltp/sgfood_oltp.sql

\connect sgfood_dw
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS intermediate;
CREATE SCHEMA IF NOT EXISTS marts;
\i /sql/01_raw_ddl.sql
