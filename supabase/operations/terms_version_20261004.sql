-- Add the current text without changing historical receipts or documents.
INSERT INTO public.terms_versions(version, document_hash)
VALUES ('2026-10-04', '870c5ad05629ad51bc5f298842dc4b3698db8bcc420e5067e343dedbb34a49d9')
ON CONFLICT (version) DO NOTHING;
