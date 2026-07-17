# Supabase Boundary

Supabase is the planned production cloud platform for Auth, Postgres, Storage, and Edge Functions. Phase 1 intentionally contains no schema, migrations, generated client, credentials, or network implementation.

Schema and adapter work begins in Phase 3 after workflow rules and authorization decisions are confirmed. The implementation should conform to the repository protocols in `MasterDanceCore`, enforce access with Row Level Security, keep service-role credentials off client devices, and model user-defined course reference entities as normal tables rather than enums.

Local secrets belong in an ignored `.env`; `.env.example` contains names only.
