function switchTab(tab) {
	activeTab = $('li.cbi-tab');
	activeTab.addClass('cbi-tab-disabled');
	activeTab.removeClass('cbi-tab');

	var selectTab = $('li[data-tab=' + tab + ']');
	selectTab.addClass('cbi-tab');
	selectTab.removeClass('cbi-tab-disabled');

	activeContainer = $('div[data-tab-active=true]');
	if (activeContainer)
		activeContainer.removeAttr('data-tab-active');

	selectContainer = $('div[data-tab=' + tab + ']');
	if (selectContainer)
		selectContainer.attr('data-tab-active', 'true');
}

function switchTabPonStatus(tab) {
	switchTab(tab);

	pontop = $('#syslog');

	pontop.text("Loading...");
	$.ajax({
		url: 'pontop/' + tab,
		dataType: 'text'
	}).done(function(data) {
		pontop.text(data);
	});
}
