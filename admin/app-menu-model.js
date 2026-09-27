export const icons = ['', 'help', 'share', 'security', 'backup', 'folder', 'star', 'cards', 'home', 'display', 'location', 'notifications', 'language', 'link'];
export const actions = ['help','support','share','lock','hidePins','privacy','backupAuto','backupNow','restore','folders','favoritesFirst','favoritesHome','sorting','start','clarity','location','radius','distances','nearbyFirst','nearbyHome','brightness','awake','notifications','language','plus','device','external'];
export function safeUrl(value) {
  if (typeof value !== 'string' || value.length > 2048 || /\s/.test(value)) return false;
  try { const u = new URL(value); return u.protocol === 'https:' && u.hostname.includes('.') && !u.username && !u.password; } catch { return false; }
}
const localized = (v, max, required = false) => v && ['nl','en'].every(l => typeof v[l] === 'string' && v[l].length <= max && (!required || v[l].trim()));
export function validateMenu(config) {
  const errors = [];
  if (!config || config.schemaVersion !== 1 || JSON.stringify(config).length > 100000) return ['Ongeldige menuversie of menu te groot.'];
  if (!safeUrl(config.share?.url) || !localized(config.share?.text, 2000, true)) errors.push('Vul een geldige HTTPS-deellink en deeltekst in beide talen in.');
  if (!Array.isArray(config.sections) || !config.sections.length || config.sections.length > 20) return [...errors, 'Gebruik 1 tot 20 categorieën.'];
  const sectionIds = new Set(), itemIds = new Set(), actionIds = new Set(); let count = 0, privacy = false;
  const validId = v => typeof v === 'string' && /^[a-zA-Z0-9_-]{1,64}$/.test(v);
  for (const s of config.sections) {
    if (!s || !validId(s.id) || sectionIds.has(s.id) || !localized(s.title,120,true) || !localized(s.description,500) || !icons.includes(s.icon) || typeof s.collapsed !== 'boolean' || typeof s.hidden !== 'boolean' || !Array.isArray(s.items)) return [...errors, 'Controleer de categorieën, vertalingen en unieke namen.'];
    sectionIds.add(s.id);
    for (const i of s.items) {
      if (++count > 100 || !i || !validId(i.id) || itemIds.has(i.id) || !actions.includes(i.action) || !icons.includes(i.icon) || !localized(i.title,120) || !localized(i.description,500) || typeof i.hidden !== 'boolean' || !['all','free','plus','locked'].includes(i.audience)) return [...errors, 'Controleer de menu-items (maximaal 100).'];
      itemIds.add(i.id);
      if (i.action !== 'external' && actionIds.has(i.action)) errors.push('Elke appfunctie kan één keer in het menu staan.');
      actionIds.add(i.action);
      if (i.action === 'external' && (!safeUrl(i.url) || !localized(i.title,120,true))) errors.push('Geef elke weblink een HTTPS-adres en een titel in beide talen.');
      if (i.action === 'privacy' && i.audience === 'all' && !i.hidden && !s.hidden) privacy = true;
    }
  }
  if (!privacy) errors.push('Privacy moet zichtbaar blijven voor iedereen, in een zichtbare categorie.');
  return errors;
}
export function visibleItems(section, plus) {
  return section.hidden ? [] : section.items.filter(i => !i.hidden && (i.audience !== 'free' || !plus) && (i.audience !== 'plus' || plus));
}
export function moveItem(config, fromSection, itemId, toSection, beforeId = null) {
  const from = config.sections.find(s => s.id === fromSection), to = config.sections.find(s => s.id === toSection);
  const index = from?.items.findIndex(i => i.id === itemId) ?? -1;
  if (!to || index < 0 || itemId === beforeId) return false;
  const [item] = from.items.splice(index, 1); const before = to.items.findIndex(i => i.id === beforeId);
  to.items.splice(before < 0 ? to.items.length : before, 0, item); return true;
}
