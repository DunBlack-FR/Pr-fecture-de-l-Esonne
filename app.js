import { SUPABASE_URL, SUPABASE_ANON_KEY } from './supabase-config.js';

const $ = (selector) => document.querySelector(selector);
const dialog = $('#auth-dialog');
const status = $('#auth-status');
const configNote = $('#config-note');
const loginForm = $('#login-form');
const signupForm = $('#signup-form');
const recoveryForm = $('#recovery-form');
const sessionPanel = $('#auth-session');
const signoutButton = $('#signout');
const adminLink = $('#admin-link');
const resendButton = $('#resend-confirmation');
const emailInput = $('#email');
let supabase = null;
let pendingConfirmationEmail = '';
let redirectTimer = null;

const validProjectUrl = /^https:\/\/[a-z0-9-]+\.supabase\.co$/i.test(SUPABASE_URL)
  && !/YOUR|VOTRE|EXAMPLE|PROJECT|placeholder/i.test(SUPABASE_URL);
const validPublicKey = typeof SUPABASE_ANON_KEY === 'string'
  && SUPABASE_ANON_KEY.length > 30
  && !/YOUR|VOTRE|EXAMPLE|PROJECT|placeholder/i.test(SUPABASE_ANON_KEY)
  && (SUPABASE_ANON_KEY.startsWith('eyJ') || SUPABASE_ANON_KEY.startsWith('sb_publishable_'));
const configHasSecretShape = typeof SUPABASE_ANON_KEY === 'string'
  && (SUPABASE_ANON_KEY.startsWith('sb_secret_') || /^service_role$/i.test(SUPABASE_ANON_KEY));
const configured = validProjectUrl && validPublicKey;

function say(message, kind = 'info') {
  status.textContent = message;
  status.dataset.kind = kind;
}

function showMode(mode) {
  clearTimeout(redirectTimer);
  loginForm.hidden = mode !== 'login';
  signupForm.hidden = mode !== 'signup';
  recoveryForm.hidden = mode !== 'recovery';
  sessionPanel.hidden = mode !== 'session';
  adminLink.hidden = mode !== 'session';
  resendButton.hidden = !(pendingConfirmationEmail && mode === 'login');
  $('#auth-title').textContent = mode === 'signup' ? 'Créer un compte'
    : mode === 'recovery' ? 'Nouveau mot de passe'
    : mode === 'session' ? 'Session ouverte' : 'Connexion';
  say('');
}

async function callAuth(action) {
  try { return { response: await action(), thrown: null }; }
  catch (thrown) { return { response: null, thrown }; }
}

function friendlyAuthError(error, operation) {
  const message = String(error?.message || '').toLowerCase();
  const statusCode = Number(error?.status || 0);
  if (message.includes('invalid login credentials')) return 'Identifiants incorrects. Vérifiez l’adresse et le mot de passe.';
  if (message.includes('email not confirmed')) return 'Adresse non confirmée. Ouvrez le lien reçu par courriel, puis réessayez.';
  if (message.includes('user already registered')) return 'Un compte existe déjà avec cette adresse. Essayez de vous connecter ou demandez un lien de réinitialisation.';
  if (message.includes('password should be at least') || message.includes('password is too short')) return 'Mot de passe trop court selon la règle configurée dans Supabase.';
  if (message.includes('email rate limit') || statusCode === 429) return 'Trop de demandes rapprochées. Patientez avant de réessayer.';
  if (message.includes('signup is disabled')) return 'La création de comptes est désactivée dans les paramètres Auth de ce projet Supabase.';
  if (message.includes('redirect') || message.includes('site url')) return 'Redirection refusée par Supabase. Ajoutez l’adresse de ce site à la liste des URL autorisées.';
  if (message.includes('network') || message.includes('fetch')) return 'Le service Supabase est injoignable. Vérifiez la connexion et le chargement du SDK.';
  if (operation === 'signup') return 'Création impossible. Vérifiez les paramètres Auth, la politique de mot de passe et la configuration des courriels.';
  if (operation === 'recovery') return 'Envoi impossible. Vérifiez l’adresse du site autorisée et le service de courriel Supabase.';
  if (operation === 'resend') return 'Impossible de renvoyer le message. Patientez et vérifiez les réglages de courriel Supabase.';
  return 'Opération refusée par Supabase. Vérifiez les identifiants et la configuration Auth du projet.';
}

function redirectToAdmin() {
  say('Connexion réussie. Ouverture de l’espace interne…', 'success');
  redirectTimer = setTimeout(() => {
    window.location.assign(new URL('admin.html', document.baseURI).href);
  }, 900);
}

if (configured) {
  try {
    const { createClient } = await import('https://esm.sh/@supabase/supabase-js@2');
    supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
    });
    configNote.hidden = true;
    const { data, error } = await supabase.auth.getSession();
    if (error) throw error;
    if (data.session) showMode('session');
    supabase.auth.onAuthStateChange((event, session) => {
      if (event === 'PASSWORD_RECOVERY') {
        showMode('recovery');
        say('Définissez votre nouveau mot de passe.', 'info');
      } else if (event === 'SIGNED_OUT' || !session) {
        showMode('login');
      } else if (event === 'SIGNED_IN' || event === 'TOKEN_REFRESHED' || event === 'USER_UPDATED') {
        showMode('session');
        if (event === 'SIGNED_IN' && !pendingConfirmationEmail) say('Session Supabase ouverte.', 'success');
      }
    });
  } catch (error) {
    configNote.textContent = 'Impossible d’initialiser le client Supabase. Vérifiez la connexion réseau, le chargement du SDK et la configuration publique du projet.';
    say('Service d’authentification indisponible pour le moment.', 'error');
  }
} else {
  configNote.hidden = false;
  say(configHasSecretShape
    ? 'Configuration bloquée : une clé secrète/service_role ne peut pas être utilisée dans un navigateur.'
    : 'Authentification inactive : configurez les valeurs publiques valides du projet dans supabase-config.js.', 'error');
}

$('#show-signup').addEventListener('click', () => showMode('signup'));
$('#show-login').addEventListener('click', () => showMode('login'));

loginForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  if (!supabase) return say('Connexion indisponible : configuration Supabase manquante ou invalide.', 'error');
  if (!loginForm.reportValidity()) return;
  say('Connexion en cours…');
  const { response, thrown } = await callAuth(() => supabase.auth.signInWithPassword({
    email: emailInput.value.trim(), password: $('#password').value
  }));
  const error = thrown || response?.error;
  if (error) return say(friendlyAuthError(error, 'login'), 'error');
  pendingConfirmationEmail = '';
  loginForm.reset();
  redirectToAdmin();
});

signupForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  if (!supabase) return say('Création indisponible : configuration Supabase manquante ou invalide.', 'error');
  if (!signupForm.reportValidity()) return;
  const email = signupForm.elements.email.value.trim();
  const password = signupForm.elements.password.value;
  if (password.length < 8) return say('Le mot de passe doit comporter au moins 8 caractères.', 'error');
  if (password !== signupForm.elements['confirm-password'].value) return say('Les deux mots de passe ne correspondent pas.', 'error');
  say('Création du compte en cours…');
  const { response, thrown } = await callAuth(() => supabase.auth.signUp({
    email,
    password,
    options: { emailRedirectTo: new URL('index.html', document.baseURI).href }
  }));
  const error = thrown || response?.error;
  if (error) return say(friendlyAuthError(error, 'signup'), 'error');
  const { data } = response;
  signupForm.reset();
  if (data.session) {
    pendingConfirmationEmail = '';
    showMode('session');
    say('Compte créé et connecté. Si la confirmation est activée, consultez aussi votre courriel. Le rôle par défaut du schéma fourni est viewer; l’administration reste réservée aux profils admin.', 'success');
  } else {
    pendingConfirmationEmail = email;
    emailInput.value = email;
    showMode('login');
    resendButton.hidden = false;
    say('Demande reçue. Si l’adresse peut être enregistrée, un courriel de confirmation lui sera envoyé. Confirmez-la avant la première connexion.', 'success');
  }
});

resendButton.addEventListener('click', async () => {
  if (!supabase || !pendingConfirmationEmail) return say('Aucune demande de confirmation en attente dans cette page.', 'error');
  const { response, thrown } = await callAuth(() => supabase.auth.resend({
    type: 'signup', email: pendingConfirmationEmail,
    options: { emailRedirectTo: new URL('index.html', document.baseURI).href }
  }));
  const error = thrown || response?.error;
  if (error) return say(friendlyAuthError(error, 'resend'), 'error');
  say('Si cette adresse est en attente de confirmation, un nouveau message a été demandé.', 'success');
});

$('#reset-password').addEventListener('click', async () => {
  if (!supabase) return say('Réinitialisation indisponible avant la configuration Supabase.', 'error');
  const email = emailInput.value.trim();
  if (!email) return say('Saisissez votre adresse courriel avant de demander un lien de réinitialisation.', 'error');
  const { response, thrown } = await callAuth(() => supabase.auth.resetPasswordForEmail(email, {
    redirectTo: new URL('index.html', document.baseURI).href
  }));
  const error = thrown || response?.error;
  if (error) return say(friendlyAuthError(error, 'recovery'), 'error');
  say('Si cette adresse est enregistrée, un courriel de réinitialisation sera envoyé.', 'success');
});

recoveryForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  if (!supabase) return say('Connexion Supabase non configurée.', 'error');
  if (!recoveryForm.reportValidity()) return;
  const password = recoveryForm.elements['new-password'].value;
  const confirmation = recoveryForm.elements['confirm-password'].value;
  if (password.length < 8 || password !== confirmation) return say('Le mot de passe doit avoir au moins 8 caractères et correspondre dans les deux champs.', 'error');
  const { response, thrown } = await callAuth(() => supabase.auth.updateUser({ password }));
  const error = thrown || response?.error;
  if (error) return say(friendlyAuthError(error, 'recovery'), 'error');
  recoveryForm.reset();
  showMode('session');
  say('Mot de passe modifié. Votre session est ouverte.', 'success');
});

$('#cancel-recovery').addEventListener('click', () => showMode('login'));
signoutButton.addEventListener('click', async () => {
  if (!supabase) return;
  const { response, thrown } = await callAuth(() => supabase.auth.signOut());
  if (thrown || response?.error) return say('La déconnexion a échoué. Réessayez.', 'error');
  pendingConfirmationEmail = '';
  showMode('login');
  say('Session Supabase fermée.', 'success');
});
