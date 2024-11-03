'use strict';
'require baseclass';

return baseclass.extend({
	title: _('PON Status'),

	load: function () {
		return L.Request.get(L.url('admin/8311/gpon_status')).then(function (res) {
			return res.json();
		});
	},

	render: function (data) {
		var fields = [
			_('PON Mode'), data.pon_mode || '?',
			_('PON PLOAM Status'), data.status || '?',
			_('Receive / Transmit Optical Power'), data.power || '?',
			_('CPU / Laser Temperature'), data.temperature || '?',
			_('Module Info'), data.module_info || '?',
			_('ETH Speed'), data.eth_speed || '?',
			_('Active Firmware'), data.active_bank || '?'
		];

		var table = E('div', { 'class': 'table' });

		for (var i = 0; i < fields.length; i += 2) {
			table.appendChild(E('div', { 'class': 'tr' }, [
				E('div', { 'class': 'td left', 'width': '33%' }, [fields[i]]),
				E('div', { 'class': 'td left' }, [fields[i + 1]])
			]));
		}

		return table;
	}
});
