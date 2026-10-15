// IAMJARL marketing kit v1.32.2: generated from kit/kit.js, do not edit
// The marketing kit's motion (#65): the two things that move, and nothing else.
//
//   video.ij-loop      a short, muted screen recording in a phone. It plays
//                      while it is on screen and pauses when it is not.
//   .ij-tour           the phone that stays: one phone holds still while the
//                      feature texts scroll past, and its screen changes with
//                      the text in the middle of the viewport.
//
// CSS does the moving, with the motion tokens; this module only decides when.
// No library: the owner chose a small observer over vendoring Motion.
//
// The page never waits for it. Without it, or with "reduce motion" on, the
// video shows its poster and the tour its row of screens: the resting state is
// the whole page, in the served HTML. It also steps back if the visitor turns
// on "reduce motion" while the page is open.

const REDUCE = '(prefers-reduced-motion: reduce)';
const WIDE = '(min-width: 768px)';

const reduce = matchMedia(REDUCE);
const wide = matchMedia(WIDE);

function loops(root) {
  const videos = [...root.querySelectorAll('video.ij-loop')];
  if (!videos.length) return;
  const seen = new IntersectionObserver(entries => {
    for (const e of entries) {
      const v = e.target;
      if (e.isIntersecting && !reduce.matches) {
        v.preload = 'auto';
        v.play().catch(() => { /* blocked or no source: the poster stays */ });
      } else {
        v.pause();
      }
    }
  }, { threshold: 0.4 });
  for (const v of videos) {
    // Muted and inline are what let a browser play it unasked; set them in
    // case the markup forgot, so a missing attribute cannot block it.
    v.muted = true;
    v.playsInline = true;
    seen.observe(v);
  }
  reduce.addEventListener('change', () => { if (reduce.matches) videos.forEach(v => v.pause()); });
}

function tour(el) {
  const steps = [...el.querySelectorAll('.ij-tour__step[data-step]')];
  const screens = [...el.querySelectorAll('.ij-tour__screens > [data-step]')];
  if (steps.length < 2 || !screens.length) return;

  let watcher = null;
  const show = step => {
    el.dataset.active = step;
    for (const s of screens) s.classList.toggle('is-active', s.dataset.step === step);
    for (const s of steps) s.classList.toggle('is-active', s.dataset.step === step);
  };
  const live = () => {
    el.classList.add('is-live');
    show(steps[0].dataset.step);
    // The step crossing the middle of the viewport is the one shown.
    watcher = new IntersectionObserver(entries => {
      const hit = entries.filter(e => e.isIntersecting).pop();
      if (hit) show(hit.target.dataset.step);
    }, { rootMargin: '-45% 0px -45% 0px' });
    steps.forEach(s => watcher.observe(s));
    // Crossfades only from the next frame: becoming live must not animate.
    requestAnimationFrame(() => requestAnimationFrame(() => el.classList.add('is-ready')));
  };
  const rest = () => {
    watcher?.disconnect();
    watcher = null;
    el.classList.remove('is-live', 'is-ready');
    delete el.dataset.active;
    for (const s of [...screens, ...steps]) s.classList.remove('is-active');
  };
  const decide = () => (!reduce.matches && wide.matches ? (watcher || live()) : rest());
  decide();
  reduce.addEventListener('change', decide);
  wide.addEventListener('change', decide);
}

export function enhance(root = document) {
  loops(root);
  root.querySelectorAll('.ij-tour').forEach(tour);
}

if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', () => enhance());
else enhance();
