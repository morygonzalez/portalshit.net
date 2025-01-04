document.addEventListener('DOMContentLoaded', () => {
  document.querySelector('#date_picker input[type="date"]').onchange = (event) => {
    event.preventDefault();
    const date = event.target.value;
    if (location.href.match(date) == null) {
      location.href = `/popular/${date}`;
    }
  }
});
