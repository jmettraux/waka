
var typeClick = function(ev) {

  var table = H.elt('table.upcoming');

  if (table._typeFiltered) {
    H.unhide(table, 'tr');
    table._typeFiltered = false;
  }
  else {
    table._typeFiltered = true;
    var t = ev.target.textContent.trim();
    H.hide(table, 'tr:not(.' + t + ')');
  }
};

H.on('td.type', 'click', typeClick);

