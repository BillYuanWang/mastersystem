begin;
select plan(4);
select has_column('public', 'billing_invoice_items', 'schedule_snapshot');
select col_type_is('public', 'billing_invoice_items', 'schedule_snapshot', 'jsonb');
select ok(exists(select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'admin_issue_billing_invoice_scoped_dual_v3'), 'v3 issuance RPC exists');
select ok(not has_function_privilege('anon',
  'public.admin_issue_billing_invoice_scoped_dual_v3(uuid,uuid,uuid,uuid[],text,integer,text,timestamptz,text,uuid,uuid,text,uuid,text,jsonb)',
  'execute'), 'anonymous clients cannot issue billing snapshots');
select * from finish();
rollback;
