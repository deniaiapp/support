import { createFileRoute, redirect } from '@tanstack/react-router';
import { resolveLanguage } from '@/lib/i18n';

// The feedback form lives in the support widget. This URL opens it on the help
// center home; the widget reads `?support=`.
export const Route = createFileRoute('/$lang/feedback')({
  beforeLoad: ({ params }) => {
    throw redirect({ href: `/${resolveLanguage(params.lang)}?support=feedback` });
  },
});
