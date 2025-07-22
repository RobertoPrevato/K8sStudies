document.addEventListener("DOMContentLoaded", function () {
    function setFullScreen() {
        localStorage.setItem("FULLSCREEN", "Y")
        document.documentElement.classList.add("fullscreen");
    }
    function exitFullScreen() {
        localStorage.setItem("FULLSCREEN", "N")
        document.documentElement.classList.remove("fullscreen");
    }

    // Select all radio inputs with the name "__fullscreen"
    const fullscreenRadios = document.querySelectorAll('input[name="__fullscreen"]');

    // Add a change event listener to each radio input
    fullscreenRadios.forEach(function (radio) {
        radio.addEventListener("change", function () {
            if (radio.checked) {
                if (radio.id === "__fullscreen") {
                    setFullScreen();
                } else if (radio.id === "__fullscreen_no") {
                    exitFullScreen();
                }
            }
        });
    });
});
