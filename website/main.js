// VitalU website: load sequence, phone screens, scroll reveals, tool filter, FAQ.
(() => {
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const $ = (s, el = document) => el.querySelector(s);
  const $$ = (s, el = document) => [...el.querySelectorAll(s)];

  // Hand-drawn strokes: give each path its own length so it can draw in.
  $$('.draw').forEach((p) => {
    const len = Math.ceil(p.getTotalLength ? p.getTotalLength() : 1000);
    p.style.setProperty('--len', len);
  });

  // Hero load sequence.
  const hero = $('.hero');
  const art = $('.hero-art');
  const start = () => {
    document.body.classList.add('loaded');
    setTimeout(() => hero.classList.add('drawn'), 700);
    setTimeout(() => art.classList.add('tracking'), 2600);
  };
  (document.fonts ? document.fonts.ready : Promise.resolve()).then(() => requestAnimationFrame(start));

  // Nav: background once scrolled, and highlight the section in view.
  const nav = $('.nav');
  const onScroll = () => nav.classList.toggle('is-scrolled', scrollY > 10);
  addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  const navLinks = $$('.links a');
  const spy = new IntersectionObserver((entries) => {
    entries.forEach((e) => {
      if (!e.isIntersecting) return;
      const href = e.target === hero ? '#top' : '#' + e.target.id;
      navLinks.forEach((a) => a.classList.toggle('is-on', a.getAttribute('href') === href));
    });
  }, { rootMargin: '-45% 0px -50% 0px' });
  [hero, ...['features', 'tools', 'help', 'faq'].map((id) => document.getElementById(id))].forEach((el) => spy.observe(el));

  // Scroll reveals, stroke drawing and the crowd of people in the help section.
  const io = new IntersectionObserver((entries) => {
    entries.forEach((e) => {
      if (!e.isIntersecting) return;
      const el = e.target;
      el.classList.add('is-in', 'drawn');
      if (el.matches('.band')) countUp(el);
      io.unobserve(el);
    });
  }, { threshold: 0.18 });
  $$('.reveal, .crowd, .band').forEach((el) => io.observe(el));

  // Stagger siblings that reveal together.
  $$('.way-in, .cards').forEach((group) => {
    $$('.reveal', group).forEach((el, i) => (el.style.transitionDelay = i * 0.1 + 's'));
  });

  function countUp(band) {
    $$('[data-count]', band).forEach((el) => {
      const to = +el.dataset.count;
      if (reduce) return;
      const t0 = performance.now();
      const dur = 1400;
      const tick = (t) => {
        const k = Math.min(1, (t - t0) / dur);
        el.textContent = Math.round(to * (1 - Math.pow(1 - k, 3)));
        if (k < 1) requestAnimationFrame(tick);
      };
      el.textContent = '0';
      requestAnimationFrame(tick);
    });
  }

  // Phone screens: Home, Water, Meals, Help. They rotate on their own and the
  // buttons under the hero jump straight to one.
  const screens = $$('.scr');
  const tabs = $$('.screen-dots button');
  const tabbar = $$('.tabbar span');
  const tabFor = [0, 1, 3, 4];
  const dots = $('.screen-dots');
  const DWELL = 4500;
  let cur = 0, timer = 0, left = DWELL, since = 0, paused = false;

  function show(n) {
    if (n === cur) return;
    const prev = screens[cur];
    prev.classList.remove('is-on');
    prev.classList.add('is-out');
    setTimeout(() => prev.classList.remove('is-out'), 600);
    cur = n;
    screens[n].classList.add('is-on');
    tabs.forEach((t, i) => t.setAttribute('aria-selected', i === n));
    tabbar.forEach((t, i) => t.classList.toggle('is-on', i === tabFor[n]));
    if (n === 1) water();
  }

  function water() {
    const el = $('[data-water]');
    if (reduce) return;
    const t0 = performance.now();
    const tick = (t) => {
      const k = Math.min(1, (t - t0) / 1600);
      el.textContent = (1.4 * (1 - Math.pow(1 - k, 3))).toFixed(1);
      if (k < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  }

  function schedule(ms) {
    clearTimeout(timer);
    left = ms;
    since = performance.now();
    timer = setTimeout(() => { show((cur + 1) % screens.length); schedule(DWELL); }, ms);
  }
  function pause() {
    if (paused) return;
    paused = true;
    clearTimeout(timer);
    left = Math.max(400, left - (performance.now() - since));
    dots.classList.add('is-paused');
  }
  function resume() {
    if (!paused) return;
    paused = false;
    dots.classList.remove('is-paused');
    schedule(left);
  }

  dots.style.setProperty('--dwell', DWELL / 1000 + 's');
  tabs.forEach((t, i) => t.addEventListener('click', () => {
    show(i);
    if (!reduce) { paused = false; dots.classList.remove('is-paused'); schedule(DWELL); }
  }));

  if (reduce) {
    dots.classList.add('is-paused');
  } else {
    setTimeout(() => schedule(DWELL), 1200);
    art.addEventListener('pointerenter', pause);
    art.addEventListener('pointerleave', resume);
    new IntersectionObserver(([e]) => (e.isIntersecting ? resume() : pause())).observe(art);
    document.addEventListener('visibilitychange', () => (document.hidden ? pause() : resume()));
  }

  // Hero parallax: layers follow the pointer by their own depth.
  if (!reduce && matchMedia('(pointer: fine)').matches) {
    const layers = $$('[data-depth]', art);
    let raf = 0;
    hero.addEventListener('pointermove', (e) => {
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => {
        const r = hero.getBoundingClientRect();
        const x = (e.clientX - r.left) / r.width - 0.5;
        const y = (e.clientY - r.top) / r.height - 0.5;
        layers.forEach((l) => {
          const d = +l.dataset.depth;
          l.style.setProperty('--mx', (-x * d).toFixed(1) + 'px');
          l.style.setProperty('--my', (-y * d).toFixed(1) + 'px');
        });
      });
    });
    hero.addEventListener('pointerleave', () => layers.forEach((l) => {
      l.style.setProperty('--mx', '0px');
      l.style.setProperty('--my', '0px');
    }));
  }

  // Tool filter with a sliding pill.
  const seg = $('.seg');
  const pill = $('.seg-pill');
  const segBtns = $$('button', seg);
  const items = $$('#tool-grid li');
  const placePill = (btn) => {
    pill.style.width = btn.offsetWidth + 'px';
    pill.style.transform = `translateX(${btn.offsetLeft}px)`;
  };
  segBtns.forEach((b) => b.addEventListener('click', () => {
    segBtns.forEach((x) => x.setAttribute('aria-selected', x === b));
    placePill(b);
    b.scrollIntoView({ block: 'nearest', inline: 'center', behavior: reduce ? 'auto' : 'smooth' });
    const f = b.dataset.f;
    const keep = (li) => f === 'all' || li.dataset.c === f;
    items.forEach((li) => { if (!keep(li)) li.classList.add('is-hiding'); });
    setTimeout(() => {
      items.forEach((li) => {
        const k = keep(li);
        li.hidden = !k;
        if (k) li.classList.add('is-hiding');
      });
      requestAnimationFrame(() => requestAnimationFrame(() => {
        items.filter(keep).forEach((li, i) => {
          li.style.transitionDelay = i * 0.03 + 's';
          li.classList.remove('is-hiding');
        });
      }));
    }, reduce ? 0 : 260);
  }));
  const placeCurrent = () => placePill($('[aria-selected="true"]', seg));
  (document.fonts ? document.fonts.ready : Promise.resolve()).then(placeCurrent);
  addEventListener('resize', placeCurrent);

  // FAQ: open and close with a height animation.
  $$('.qa details').forEach((d) => {
    const sum = $('summary', d);
    const body = $('div', d);
    sum.addEventListener('click', (e) => {
      if (reduce) return;
      e.preventDefault();
      if (d.open) {
        const h = body.offsetHeight;
        body.animate([{ height: h + 'px', opacity: 1 }, { height: '0px', opacity: 0 }], { duration: 320, easing: 'cubic-bezier(.2,.8,.2,1)' })
          .onfinish = () => (d.open = false);
      } else {
        d.open = true;
        const h = body.offsetHeight;
        body.animate([{ height: '0px', opacity: 0 }, { height: h + 'px', opacity: 1 }], { duration: 380, easing: 'cubic-bezier(.2,.8,.2,1)' });
      }
    });
  });
})();
