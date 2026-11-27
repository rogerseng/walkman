// Casseti's website: two small niceties. Everything works without this file.
document.documentElement.classList.add('js');
const still = matchMedia('(prefers-reduced-motion: reduce)').matches;

// Things come up into place as they are scrolled to.
const seen = new IntersectionObserver((entries) => {
  for (const entry of entries) {
    if (entry.isIntersecting) { entry.target.classList.add('seen'); seen.unobserve(entry.target); }
  }
}, { rootMargin: '0px 0px -8% 0px' });
document.querySelectorAll('.reveal').forEach((el) => seen.observe(el));

// Questions ease open and shut instead of snapping.
document.querySelectorAll('details').forEach((item) => {
  const summary = item.querySelector('summary');
  const answer = document.createElement('div');
  answer.className = 'answer';
  while (summary.nextSibling) answer.appendChild(summary.nextSibling);
  item.appendChild(answer);
  item.classList.add('eased');
  if (item.open) item.classList.add('open');
  let moving = null;
  summary.addEventListener('click', (event) => {
    if (still) { item.classList.toggle('open', !item.open); return; }
    event.preventDefault();
    if (moving) moving.cancel();
    if (item.classList.contains('open')) {
      item.classList.remove('open');
      moving = answer.animate({ height: [answer.offsetHeight + 'px', '0px'], opacity: [1, 0] },
                              { duration: 260, easing: 'ease' });
      moving.onfinish = () => { item.open = false; moving = null; };
    } else {
      item.open = true;
      item.classList.add('open');
      moving = answer.animate({ height: ['0px', answer.offsetHeight + 'px'], opacity: [0, 1] },
                              { duration: 300, easing: 'ease' });
      moving.onfinish = () => { moving = null; };
    }
  });
});

// The clip of the deck stays still for anyone who has asked for less motion.
if (still) document.querySelectorAll('video').forEach((clip) => { clip.removeAttribute('autoplay'); clip.pause(); });
