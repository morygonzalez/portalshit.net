document.addEventListener('DOMContentLoaded', () => {
  document.querySelector('#date_picker input[type="date"]').onblur = (event) => {
    event.preventDefault();
    const date = event.target.value;
    if (location.href.match(date) == null) {
      location.href = `/popular/${date}`;
    }
  }
});
