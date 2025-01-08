create extension if not exists "uuid-ossp";


-- delete all tables and types
-- Suppression des tables qui ont des clés étrangères
drop table if exists public.notification cascade;
drop table if exists public.transaction cascade;
drop table if exists public.validation cascade;
drop table if exists public.proof cascade;
drop table if exists public.trip cascade;
drop table if exists public.account cascade;
drop table if exists public.customer cascade;
drop table if exists public.customer_type cascade;
drop table if exists public.currency cascade;
drop table if exists public.bank cascade;
drop table if exists public.prefered_template cascade;
drop table if exists public.rule cascade;
drop table if exists public.rule_condition cascade;
drop table if exists public.transaction_beta cascade;
drop table if exists public.category cascade;

-- Deletion of enumerated types
drop type if exists public.transaction_type;
drop type if exists public.trip_status;
drop type if exists public.balance_flag_type;
drop type if exists public.notification_type;
drop type if exists public.bank_condition_operator;
drop type if exists public.bank_rule_target;
drop type if exists public.bank_validity_time;
drop type if exists public.card_type;


-- Custome type creation
create type public.transaction_type as enum ('outside', 'online');
create type public.trip_status as enum ('on_hold', 'in_progress', 'ended');
create type public.balance_flag_type as enum ('green', 'orange', 'red');
create type public.notification_type as enum ('formal_notice', 'notification', 'alert');
create type public.bank_condition_operator as enum ('=', '<', '>', '<=', '>=', '!=');
create type public.bank_rule_target as enum ('trip', '', 'balance_flag+orange', 'balance_flag+red', 'notification');
create type public.bank_validity_time as enum ('permanent', 'period');
create type card_type as enum ( 'debit', 'credit', 'prepaid', 'debit_differed', 'withdrawal', 'international', 'virtual' );

-- Create custom tables

create table if not exists public.bank
(
    id      uuid    default uuid_generate_v4() not null primary key,
    name             varchar                            not null unique,
    address          varchar,
    city             varchar(50),
    country          varchar(50),
    logo             bytea,
    phone            varchar(20),
    email            varchar(100) not null unique,
    thresold         numeric(10, 2) default 5000000.00 not null,
    created_at  timestamptz          default current_timestamp not null,
    updated_at  timestamptz          default current_timestamp not null,
    created_by  uuid,
    updated_by  uuid,

    constraint valid_phone
        check ( phone ~ '^[0-9]{10,20}$' ),
    constraint valid_email
        check ( email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' ),
    constraint thresold_positive
            check ( thresold > 0 )
);

------------------------------------------------------------------
------------------------------------------------------------------

create table if not exists public.currency
(
    id      uuid    default uuid_generate_v4() not null primary key,
    code             varchar(3)                         not null unique,
    name             varchar                            not null unique,
    symbol           varchar,
    currency_rate    numeric(10, 4) not null,
    created_at  timestamptz          default current_timestamp not null,
    updated_at  timestamptz          default current_timestamp not null,
    created_by  uuid,
    updated_by  uuid
);

comment on table public.currency is 'Currency';
comment on column public.currency.id is 'Currency Identifier';
comment on column public.currency.code is 'Currency Iso code';
comment on column public.currency.name is 'Currency Name';
comment on column public.currency.symbol is 'Currency Symbol if exist';

------------------------------------------------------------------
------------------------------------------------------------------

create table if not exists public.customer_type
(
    id      uuid    default uuid_generate_v4() not null primary key,
    type            varchar(50)                        not null unique,
    description     text,
    thresold numeric,
    created_at  timestamptz          default current_timestamp not null,
    updated_at  timestamptz          default current_timestamp not null,
    created_by  uuid,
    updated_by  uuid,

    constraint thresold_positive
            check ( thresold > 0 )
);

------------------------------------------------------------------
------------------------------------------------------------------

create table if not exists public.customer
(
    id      uuid    default uuid_generate_v4() not null primary key,
    customer_type_id    uuid,
    first_name            varchar(255)                        not null,
    last_name             varchar(255),
    serial_number varchar(50),
    phone       varchar(20),
    email       varchar(100),
    balance_flag balance_flag_type default 'green' not null,
    thresold numeric,
    created_at  timestamptz          default current_timestamp not null,
    updated_at  timestamptz          default current_timestamp not null,
    created_by  uuid,
    updated_by  uuid,

     constraint customer_type_fk
        foreign key (customer_type_id) references public.customer_type(id)
        on update cascade on delete set null,
     constraint valid_phone
        check ( phone ~ '^[0-9]{10,20}$' ),
     constraint valid_email
        check ( email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' ),
     constraint thresold_positive
            check ( thresold > 0 )
);

------------------------------------------------------------------
------------------------------------------------------------------

create table if not exists public.account
(
    id      uuid    default uuid_generate_v4() not null primary key,
    number    varchar(50) not null unique,
    customer_id    uuid not null,
    created_at  timestamptz          default current_timestamp not null,
    updated_at  timestamptz          default current_timestamp not null,
    created_by  uuid,
    updated_by  uuid,

    constraint customer_fk
        foreign key (customer_id) references public.customer(id)
        on update cascade on delete restrict
);

------------------------------------------------------------------
------------------------------------------------------------------

create table if not exists public.category
(
    id      uuid    default uuid_generate_v4() not null primary key,
    type    varchar(50) not null,
    is_required boolean default true not null, -- Category is needed
    description     text,
    created_at  timestamptz          default current_timestamp not null,
    updated_at  timestamptz          default current_timestamp not null,
    created_by  uuid,
    updated_by  uuid
);

------------------------------------------------------------------
------------------------------------------------------------------

create table if not exists public.trip
(
    id      uuid    default uuid_generate_v4() not null primary key,
    customer_id    uuid not null,
    manager_user    uuid,
    validator_user  uuid,
    title           text,
    end_date              date                      not null,
    start_date            date                      not null,
    status       trip_status    default 'on_hold'   not null,
    origin       varchar(50),
    destination  varchar(50),
    proof_required boolean default true not null, -- is proof required?
    balance     numeric,
    created_at  timestamptz          default current_timestamp not null,
    updated_at  timestamptz          default current_timestamp not null,
    created_by  uuid,
    updated_by  uuid,
    serial_number varchar,

     constraint customer_fk
        foreign key (customer_id) references public.customer
        on update cascade on delete restrict,
     constraint balance_positive
            check ( balance > 0 )
);

------------------------------------------------------------------
------------------------------------------------------------------

create table if not exists public.transaction
(
    id      uuid    default uuid_generate_v4() not null primary key,
    type        transaction_type  default 'outside' not null,
    trip_id     uuid not null,
    currency_id uuid,
    amount      numeric(10, 2)                            not null,
    proof_required boolean default false not null, -- is proof required?
    country    varchar(50) not null,
    city       varchar(50),
    card_type card_type default 'debit',
    created_at  timestamptz          default current_timestamp not null,
    updated_at  timestamptz          default current_timestamp not null,
    created_by  uuid,
    updated_by  uuid,

    constraint trip_fk
        foreign key (trip_id) references public.trip(id)
        on update cascade on delete restrict,
    constraint currency_fk
        foreign key (currency_id) references public.currency(id)
        on update cascade on delete restrict,
    constraint amount_positive
            check ( amount > 0 )
);

------------------------------------------------------------------
------------------------------------------------------------------

create table if not exists public.proof
(
    id      uuid    default uuid_generate_v4() not null primary key,
    trip_id        uuid not null,
    file_id        uuid,
    is_locked      boolean  default false,
    created_at  timestamptz          default current_timestamp not null,
    updated_at  timestamptz          default current_timestamp not null,
    created_by  uuid,
    updated_by  uuid,

    constraint trip_fk
        foreign key (trip_id) references public.trip
        on update cascade on delete restrict
);

------------------------------------------------------------------
------------------------------------------------------------------

create table if not exists public.validation
(
    id      uuid    default uuid_generate_v4() not null primary key,
    transaction_id        uuid,
    proof_id              uuid,
    created_at  timestamptz          default current_timestamp not null,
    updated_at  timestamptz          default current_timestamp not null,
    created_by  uuid,
    updated_by  uuid,

    constraint transaction_fk
        foreign key (transaction_id) references public.transaction
        on update cascade on delete set null,
    constraint proof_fk
        foreign key (proof_id) references public.proof
        on update cascade on delete set null
);

------------------------------------------------------------------
------------------------------------------------------------------

create table if not exists public.prefered_template
(
    id      uuid    default uuid_generate_v4() not null primary key,
    name        varchar(50),
    is_formal   boolean default false not null, -- notice is formal or not
    url         varchar(50) not null,
    format      varchar(20),
    created_at  timestamptz          default current_timestamp not null,
    updated_at  timestamptz          default current_timestamp not null,
    created_by  uuid,
    updated_by  uuid
);

------------------------------------------------------------------
------------------------------------------------------------------

create table if not exists public.rule
(
    id      uuid    default uuid_generate_v4() not null primary key,
    name        varchar(30)                                               not null,
    validity_time bank_validity_time                                        not null,
    start_date    date,
    end_date      date,
    target        bank_rule_target                                  not null,
    created_at  timestamptz          default current_timestamp not null,
    updated_at  timestamptz          default current_timestamp not null,
    created_by  uuid,
    updated_by  uuid
);

------------------------------------------------------------------
------------------------------------------------------------------

create table if not exists public.rule_condition
(
    id      uuid    default uuid_generate_v4() not null primary key,
    rule_id      uuid,
    criteria         varchar(30)                                          not null,
    operator         bank_condition_operator                         not null,
    value            varchar,
    to_string        varchar,
    created_at  timestamptz          default current_timestamp not null,
    updated_at  timestamptz          default current_timestamp not null,
    created_by  uuid,
    updated_by  uuid,

    constraint rule_fk
        foreign key (rule_id) references public.rule(id)
        on update cascade on delete cascade
);

------------------------------------------------------------------
------------------------------------------------------------------

create table if not exists public.notification
(
    id      uuid    default uuid_generate_v4() not null primary key,
    trip_id     uuid                  not null,
    prefered_template_id     uuid     not null,
    rule_id     uuid,
    sender      varchar(50),
    type        notification_type not null,
    message     text,
    notification_sent boolean default false not null,
    notification_read boolean default false not null,
    created_at  timestamptz          default current_timestamp not null,
    updated_at  timestamptz          default current_timestamp not null,
    created_by  uuid,
    updated_by  uuid,

    constraint trip_fk
        foreign key (trip_id) references public.trip(id)
        on update cascade on delete restrict,
    constraint prefered_template_fk
        foreign key (prefered_template_id) references public.prefered_template(id)
        on update cascade on delete restrict,
    constraint rule_fk
        foreign key (rule_id) references public.rule
        on update cascade on delete restrict
);

------------------------------------------------------------------
------------------------------------------------------------------
create table if not exists public.transaction_beta
(
    id      uuid    default uuid_generate_v4() not null primary key,
    amount         numeric,
    country        varchar(50),
    city           varchar(50),
    user_bank_serialNumber varchar(50),
    transaction_date date,
    transaction_type boolean default true, -- if true, transaction outside of CEMAC else online
    accounts varchar(50)[],
    customer_type varchar(50),
    first_name varchar(50),
    last_name varchar(50),
    email varchar(100),
    phone varchar(20),
    currency varchar,
    rate numeric(10, 4),
    card_type card_type default 'debit',
    created_at  timestamptz          default current_timestamp not null,
    updated_at  timestamptz          default current_timestamp not null,
    created_by  uuid,
    updated_by  uuid,

    constraint valid_phone
        check ( phone ~ '^[0-9]{10,20}$' ),
    constraint valid_email
        check ( email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' ),
    constraint amount_positive
            check ( amount > 0 )
);


--------------------------------------------- insert data -------------------------------------------

-- Set up customer_type

insert into public.customer_type (type, description)
values
  ('standard_customer',
   'Clients with basic banking needs, such as current accounts and basic products.'),
  ('premium_customer',
   'Clients with higher income, accessing more sophisticated banking services and products.'),
  ('affluent_customer',
   'Clients with above-average income or assets, benefiting from enhanced services such as financial advice.'),
  ('young_customer',
   'Young clients or students, looking for simple banking services, often without fees.'),
  ('senior_customer',
   'Retired clients or those nearing retirement, often interested in products related to retirement planning or tailored services.'),
  ('mortgage_customer',
   'Clients who have taken out a mortgage or have specific needs related to real estate loans.'),
  ('digital_customer',
   'Clients who primarily use online banking services or mobile apps, often without any interaction in branch.'),
  ('potential_customer',
   'Prospects or clients with high growth potential, but who have not yet reached premium or affluent service levels.');

-- Setup rules and conditions