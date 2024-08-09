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

function saveConfig(e) {
	console.log("save");
	jForm = $('#8311-config');
	const form = jForm.get(0);
	const field = Array.from(form.elements);

	var valid = true;
	field.forEach(i => {
		var element = $(i);
		var element_id = element.attr('id');
		var error_label = $('label.error[for="' + element_id  + '"]');

		if (!i.checkValidity()) {
			valid = false;
			error_label.text(i.validationMessage);
			error_label.show();

			element.addClass("error");

			switchTab(element.data("cat-id"));
			element.focus();
		}
		else {
			element.removeClass("error");
			error_label.text("");
			error_label.hide();
		}
	});

	return valid;
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

function submitFirmwareForm() {
	$('input.firmware-button').attr('disabled', 'disabled');
	$('#firmware-loading').show();
	$('#firmware-form').submit();
}

function uploadFirmware() {
	if ($('#firmware-form').valid()) {
		submitFirmwareForm();
	}
}

function cancelFirmware() {
	$('#firmware-action').attr('value', 'cancel');
	submitFirmwareForm();
}

function rebootFirmware() {
	$('#firmware-action').attr('value', 'reboot');
	submitFirmwareForm();
}

function installFirmware(reboot) {
	action = 'install';
	if (reboot)
		action = 'install_reboot';

	$('#firmware-action').attr('value', action);
	submitFirmwareForm();
}
