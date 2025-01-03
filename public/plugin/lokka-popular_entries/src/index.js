document.addEventListener('DOMContentLoaded', () => {
  document.querySelector('#date_picker form').onsubmit = (event) => {
    event.preventDefault();
    const date = event.target.date.value;
    location.href = `/popular/${date}`;
  }
});
