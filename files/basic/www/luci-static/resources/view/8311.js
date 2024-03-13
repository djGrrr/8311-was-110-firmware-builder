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

function showPonMe(meId, instanceId) {
	meLabel = $('#me_label');
	meLabel.hide();
	meDump = $('#me_dump');
	meDump.hide();

	$.ajax({
		url: 'pon_dump/' + meId + '/' + instanceId,
		dataType: 'text'
	}).done(function(data) {
		meLabel.text("ME " + meId + " Instance " + instanceId);
		meLabel.show();
		meDump.text(data);
		meDump.show();
		meLabel.get(0).scrollIntoView({behavior: 'smooth'});
	});
}
