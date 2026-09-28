// The server remains the authorization boundary. This module provides enrollment
// and step-up UI; database/Edge MFA enforcement is rolled out after enrollment.
export function createAdminMfa({client, document: doc = document}) {
  const mfa = client.auth.mfa;
  let pending = null;

  async function verifiedFactors() {
    const {data, error} = await mfa.listFactors();
    if (error) throw new Error('Tweestapsverificatie kon niet worden gecontroleerd.');
    return (data?.totp || []).filter(f => f.status === 'verified');
  }

  async function prompt({factorId, enrollment = null}) {
    const dialog = doc.createElement('dialog');
    dialog.className = 'mfa-dialog';
    dialog.innerHTML = `<form><h2>Tweestapsverificatie</h2>
      <p class="mfa-intro"></p><div class="mfa-enrollment" hidden>
      <img class="mfa-qr" alt="Scan deze QR-code met je authenticator" width="220" height="220"/>
      <p>Of voer deze sleutel handmatig in:</p><code class="mfa-secret"></code>
      <p>Bewaar toegang tot je authenticator zorgvuldig. Bij verlies moet een geverifieerde beheerder je toegang herstellen.</p></div>
      <label>Code uit je authenticator<input name="code" inputmode="numeric" autocomplete="one-time-code" pattern="[0-9]{6}" maxlength="6" required/></label>
      <p class="error" role="alert"></p><div class="dialog-actions">
      <button type="button" class="secondary mfa-cancel">Annuleren</button>
      <button type="submit" class="primary">Bevestigen</button></div></form>`;
    dialog.querySelector('.mfa-intro').textContent = enrollment
      ? 'Koppel een authenticator en bevestig met de zescijferige code. Het activeren meldt andere sessies van dit account af.'
      : 'Voer de zescijferige code in om het beheer te openen.';
    if (enrollment) {
      dialog.querySelector('.mfa-enrollment').hidden = false;
      dialog.querySelector('.mfa-secret').textContent = enrollment.secret;
      // Render SVG as an image, never as executable markup in the document.
      const qr = enrollment.qr_code || '';
      if (qr.startsWith('data:image/svg+xml')) {
        dialog.querySelector('.mfa-qr').src = qr;
      } else if (qr.trimStart().startsWith('<svg')) {
        dialog.querySelector('.mfa-qr').src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(qr);
      } else {
        dialog.querySelector('.mfa-qr').hidden = true;
      }
    }
    doc.body.append(dialog);
    return new Promise((resolve, reject) => {
      let busy = false;
      const finish = () => { dialog.close(); dialog.remove(); };
      const cancel = () => {
        if (busy) return;
        finish();
        reject(new Error('Tweestapsverificatie geannuleerd.'));
      };
      dialog.addEventListener('cancel', e => { e.preventDefault(); cancel(); });
      dialog.querySelector('.mfa-cancel').addEventListener('click', cancel);
      dialog.querySelector('form').addEventListener('submit', async e => {
        e.preventDefault();
        if (busy) return;
        const input = dialog.querySelector('input');
        const code = input.value.trim();
        if (!/^\d{6}$/.test(code)) return;
        busy = true;
        dialog.querySelectorAll('button').forEach(b => b.disabled = true);
        dialog.querySelector('.error').textContent = '';
        try {
          const {error} = await mfa.challengeAndVerify({factorId, code});
          if (error) throw error;
          const assurance = await mfa.getAuthenticatorAssuranceLevel();
          if (assurance.error || assurance.data?.currentLevel !== 'aal2') throw new Error('MFA_NOT_VERIFIED');
          input.value = '';
          finish();
          resolve();
        } catch {
          input.value = '';
          dialog.querySelector('.error').textContent = 'De code kon niet worden bevestigd. Probeer een nieuwe code.';
        } finally {
          busy = false;
          dialog.querySelectorAll('button').forEach(b => b.disabled = false);
        }
      });
      dialog.showModal();
      dialog.querySelector('input').focus();
    });
  }

  async function requireExistingFactor() {
    const factors = await verifiedFactors();
    if (!factors.length) return false;
    const {data, error} = await mfa.getAuthenticatorAssuranceLevel();
    if (error) throw new Error('Tweestapsverificatie kon niet worden gecontroleerd.');
    if (data?.currentLevel !== 'aal2') await prompt({factorId: factors[0].id});
    return true;
  }

  async function enroll() {
    if (pending) return pending;
    pending = (async () => {
      if (await requireExistingFactor()) return;
      const {data, error} = await mfa.enroll({factorType:'totp',friendlyName:'PasKluis Beheer'});
      if (error || !data?.totp) throw new Error('De authenticator kon niet worden aangemaakt. Probeer het opnieuw.');
      try { await prompt({factorId:data.id,enrollment:data.totp}); }
      catch (error) {
        // Only remove the unverified factor created by this enrollment attempt.
        const {data: factors, error: listError} = await mfa.listFactors();
        if (!listError && (factors?.all || []).some(f => f.id === data.id && f.status === 'unverified')) {
          await mfa.unenroll({factorId:data.id});
        }
        throw error;
      }
    })();
    try { return await pending; } finally { pending = null; }
  }
  return {requireExistingFactor, enroll};
}
