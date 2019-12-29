
var makeClicker = function(name, classer) {

  return function(ev) {

    var table = H.elt('table.upcoming');
    table._filters = table._filters || {};

    if (table._filters[name]) {
      H.unhide(table, 'tr');
      table._filters[name] = false;
    }
    else {
      var c = classer(ev.target);
      H.hide(table, 'tr:not(.' + c + ')');
      table._filters[name] = true;
    }
  };
};

H.on(
  'td.type',
  'click',
  makeClicker('type', function(t) { return t.textContent.trim(); }));
H.on(
  'td.level',
  'click',
  makeClicker('level', function(t) { return 'l' + t.textContent.trim(); }));

