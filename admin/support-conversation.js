const escape = value => String(value ?? '').replace(/[&<>"']/g, c => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
}[c]));

export function orderedSupportMessages(messages) {
  return [...messages].sort((a, b) => {
    const time = Date.parse(a.created_at) - Date.parse(b.created_at);
    if (Number.isFinite(time) && time !== 0) return time;
    // PostgreSQL can distinguish replies within the same millisecond.
    const fraction = value => (String(value).match(/\.(\d+)/)?.[1] || '').padEnd(6, '0');
    return fraction(a.created_at).localeCompare(fraction(b.created_at)) ||
      String(a.id).localeCompare(String(b.id));
  });
}

export function supportMessageMarkup(message, {staffName, customerName = 'Klant'} = {}) {
  const automatic = message.sender_kind === 'automatic';
  const staff = message.sender_kind === 'staff';
  const name = String(message.sender_name || staffName || '').trim();
  const label = automatic ? 'Automatische ontvangstbevestiging' : staff
    ? (name ? `${name} · PasKluis` : 'Team PasKluis') : `${customerName} · Klant`;
  const date = new Date(message.created_at);
  const time = Number.isNaN(date.getTime()) ? '' : new Intl.DateTimeFormat('nl-NL', {
    day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit',
  }).format(date);
  return `<div class="message ${automatic ? 'automatic' : staff ? 'staff' : 'customer'}" data-message-id="${escape(message.id)}"><strong class="message-sender">${escape(label)}</strong>${escape(message.message)}<small>${escape(time)}</small></div>`;
}
