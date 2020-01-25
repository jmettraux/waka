
H.onDocumentReady(function() {

  var select = function(ev) {

    H.hide('.subject-detail');
    H.removeClass('.subject', '.selected');
      //
    var makeTransparent = function(e) { e.style.opacity = '0.0'; };
    H.forEach('.subject-detail .meanings', makeTransparent);
    H.forEach('.subject-detail .readings', makeTransparent);

    var id = H.getAtt(ev.target, '^[-subject-id]', '-subject-id');

    H.addClass('.subject[-subject-id="' + id + '"]', '.selected')
      //
    var sd = H.elt('.subject-detail[-subject-id="' + id + '"]');
    H.unhide(sd);
    window.setTimeout(function() {
      H.elt(sd, '.readings').style.opacity = '1.0';
      H.elt(sd, '.meanings').style.opacity = '1.0';
    }, 500);
  };

  H.on('.subject', 'mouseover', select);

  H.on('body', 'keyup', function(ev) {

    if (ev.keyCode !== 37 && ev.keyCode !== 39) return;

    var sds = H.elts('.subject-detail');
    var sd = H.elt('.subject-detail:not(.hidden)');

    if (ev.shiftKey) sd = null;

    if (sd) {
      select({ target:
        ev.keyCode === 37 ?
        sd.previousElementSibling :
        sd.nextElementSibling });
    }
    else if (ev.keyCode === 37) {
      select({ target: sds[0] });
    }
    else {
      select({ target: sds[sds.length - 1] });
    }
  });
});

