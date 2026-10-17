SET statement_timeout = 0;
-- Name: accounts; Type: TABLE
CREATE TABLE public.accounts (
    id bigint NOT NULL,
    name character varying NOT NULL,
    balance numeric(10,2) DEFAULT 0.0,
    created_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT positive_balance CHECK ((balance >= (0)::numeric))
);

CREATE TABLE "ledger_entries" (
    "id" integer PRIMARY KEY AUTOINCREMENT NOT NULL,
    "account_id" integer NOT NULL,
    "memo" text
);

CREATE UNIQUE INDEX index_accounts_on_name ON public.accounts USING btree (name);
CREATE INDEX "index_ledger_entries_on_account_id" ON "ledger_entries" ("account_id");
