# Reception Management Setup

The application now includes a **Reception Management** tab.

## New features

- Add and edit receptionist records
- Store starting date and contract termination date
- Store email, phone/WhatsApp, employment type, property assignment, and notes
- Archive former receptionists without deleting their history
- Restore archived receptionists
- View active, archived, and all receptionists
- Search and filter by property
- See contracts ending within the next 30 days

## Supabase setup

1. Open your existing Supabase project.
2. Open **SQL Editor**.
3. Run `reception_management_migration.sql` once.
4. Upload the updated `index.html` to GitHub, replacing the existing file.
5. Redeploy or wait for your hosting provider to redeploy the site.

Do not delete the existing Supabase tables or records. The migration only adds the new `receptionists` table and its security policy.
