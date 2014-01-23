// Generated by CoffeeScript 1.6.3
(function() {
  var CXLTX, TRM, alert, badge, echo, help, info, log, rpr, warn, whisper;

  TRM = require('coffeenode-trm');

  rpr = TRM.rpr.bind(TRM);

  badge = 'CXLTX/sample-provider';

  log = TRM.get_logger('plain', badge);

  info = TRM.get_logger('info', badge);

  whisper = TRM.get_logger('whisper', badge);

  alert = TRM.get_logger('alert', badge);

  warn = TRM.get_logger('warn', badge);

  help = TRM.get_logger('help', badge);

  echo = TRM.echo.bind(TRM);

  CXLTX = require('./main');

  this.helo = function(name, handler) {
    return handler(null, "{Hello, " + (CXLTX.escape(name)) + "!}");
  };

  this.page_and_line_nr = function(page_nr, line_nr, handler) {
    page_nr = parseInt(page_nr, 10);
    line_nr = parseInt(line_nr, 10);
    return handler(null, "Helo from NodeJS.\nThis paragraph appears on page " + page_nr + ", column ..., line " + line_nr + ".");
  };

  this.show_geometry = function(handler) {
    return CXLTX.read_aux((function(_this) {
      return function(error) {
        var R, g, name, names, value, _i, _len;
        if (error != null) {
          return handler(error);
        }
        if ((g = CXLTX.aux['geometry']) == null) {
          return handler("unable to retrieve geometry info from " + CXLTX.aux['auxroute'] + ";");
        }
        R = [];
        names = ((function() {
          var _results;
          _results = [];
          for (name in g) {
            _results.push(name);
          }
          return _results;
        })()).sort();
        for (_i = 0, _len = names.length; _i < _len; _i++) {
          name = names[_i];
          value = g[name];
          value = value != null ? (value.toFixed(2)).concat(' mm') : './.';
          value = value.replace(/-/g, '–');
          R.push("" + name + " & " + value);
        }
        R = R.join('\\\\\n');
        R = "\\begin{tabular}{ | l | r | }\n\\hline\n" + R + "\\\\\n\\hline\\end{tabular}";
        return handler(null, R);
      };
    })(this));
  };

  this.show_special_chrs = function(handler) {
    var R, chr, chr_by_names, name;
    chr_by_names = {
      'opening brace': '{',
      'closing brace': '}',
      'Dollar sign': '$',
      'ampersand': '&',
      'hash': '#',
      'caret': '^',
      'underscore': '_',
      'wave': '~',
      'percent sign': '%'
    };
    R = [];
    for (name in chr_by_names) {
      chr = chr_by_names[name];
      R.push("" + name + " & " + (CXLTX.escape(chr)));
    }
    R = R.join('\\\\\n');
    R = "\\begin{tabular}{ | l | c | }\n\\hline\n" + R + "\\\\\n\\hline\n\\end{tabular}";
    return handler(null, R);
  };

  this.clear_aux = function(handler) {
    var name;
    for (name in CXLTX.aux) {
      delete CXLTX.aux[name];
    }
    return handler(null);
  };

  this.show_aux = function(handler) {
    return handler(null, "\\begin{verbatim}\n" + (rpr(CXLTX.aux)) + "\n\\end{verbatim}");
  };

}).call(this);