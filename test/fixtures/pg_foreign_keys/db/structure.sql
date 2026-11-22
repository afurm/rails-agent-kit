-- Synthetic pg_dump-style schema; never executed.
CREATE TABLE public.accounts (
    id bigint NOT NULL,
    code text NOT NULL
);
CREATE TABLE public.entries (
    id bigint NOT NULL,
    account_id bigint,
    account_code text,
    parent_id bigint
);
CREATE TABLE public.unrelated (id bigint NOT NULL);
CREATE INDEX index_entries_on_account_id ON public.entries USING btree (account_id);
ALTER TABLE ONLY public.entries
    ADD CONSTRAINT fk_entries_account FOREIGN KEY (account_id) REFERENCES public.accounts(id);
alter table "public"."entries"
    add constraint "fk_entries_code" foreign key ("account_code") references "accounts"("code");
ALTER TABLE entries ADD CONSTRAINT fk_entries_parent FOREIGN KEY (parent_id) REFERENCES entries(id);
