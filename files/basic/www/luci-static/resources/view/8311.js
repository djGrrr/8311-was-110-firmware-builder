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

function saveConfig(form) {
	const field = Array.from(form.elements);
	var saveb = $('#save-btn');
	var valid = true;

	var activeTab = $('li.cbi-tab[data-tab]').attr('data-tab');
	if (activeTab) {
		localStorage.setItem('activeConfigTab', activeTab);
	}

	field.forEach(i => {
		var element = $(i);
		var element_id = element.attr('id');
		var error_label = $('label.error[for="' + element_id + '"]');

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

	if (valid) {
		saveb.attr('disabled', 'disabled');
		saveb.addClass('spinning');
	}

	return valid;
}

function vlanTables() {
	vlans = $('#syslog');

	vlans.text("Loading...");
	$.ajax({
		url: 'vlans/extvlans',
		dataType: 'text'
	}).done(function(data) {
		vlans.text(data);
	});
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

function submitSupportForm(input, action) {
	$('button.support-button').attr('disabled', 'disabled');
	$('#support-action').attr('value', action);
	var btn = $(input);
	if (btn)
		btn.addClass('spinning');

	$('#support-form').submit();
}

function submitFirmwareForm(input) {
	var btn = $(input);
	$('.firmware-button').attr('disabled', 'disabled');
	$('#firmware-file').attr('onclick', 'return false');
	if (btn)
		btn.addClass('spinning');

	$('#firmware-form').submit();
	return true;
}

function uploadFirmware(input) {
	if (!$('#firmware-form').valid())
		return false;
	$('#switch-reboot-section').hide();
	return submitFirmwareForm(input);
}

function cancelFirmware(input) {
	$('#firmware-action').attr('value', 'cancel');
	return submitFirmwareForm(input);
}

function rebootFirmware(input) {
	$('#firmware-action').attr('value', 'reboot');
	return submitFirmwareForm(input);
}

function installFirmware(input, reboot) {
	action = 'install';
	if (reboot)
		action = 'install_reboot';

	$('#firmware-action').attr('value', action);
	return submitFirmwareForm(input);
}

function showSwitchRebootConfirmation() {
	$('#switch-reboot-original').hide();
	$('#switch-reboot-confirmation').show();
}

function confirmSwitchReboot(confirm, input) {
	if (confirm) {
		$('#firmware-file').removeAttr('required');
		$('#firmware-action').val('switch_reboot');
		return submitFirmwareForm(input);
	}
	else {
		$('#switch-reboot-confirmation').hide();
		$('#switch-reboot-original').show();
	}
}

$(document).ready(function () {
	var savedTab = localStorage.getItem('activeConfigTab');
	if (savedTab) {
		switchTab(savedTab);
		localStorage.removeItem('activeConfigTab');
	}

	var fixVlansSelect = $('#widget\\.cbid\\.system\\.poncfg\\.fix_vlans');
	if (fixVlansSelect.length === 0) {
		return;
	}

	var editHookScriptBtn = $('#edit-hook-script-btn');
	var hookScriptModal = $('#hook-script-modal');
	var hookScriptMessage = $('#hook-script-message');
	var hookScriptTextarea = $('#hook-script-textarea');
	var vlanFields = $('.vlan-field');

	function toggleVlanFields() {
		var fixVlansValue = fixVlansSelect.val();
		if (fixVlansValue == '1') {
			vlanFields.show();
		} else {
			vlanFields.hide();
		}
	}

	fixVlansSelect.change(toggleVlanFields);
	toggleVlanFields();
	editHookScriptBtn.click(function (e) {
		e.preventDefault();

		hookScriptMessage.hide();
		hookScriptMessage.text('');

		$.get('get_hook_script', function (data) {
			if (data.trim() === '') {
				hookScriptTextarea.val('');
			} else {
				hookScriptTextarea.val(data);
			}
			hookScriptModal.show();
			adjustTextareaHeight();
		});
	});

	$('#hook-script-save-btn').click(function () {
		var content = hookScriptTextarea.val();
		$.post('save_hook_script', { content: content }, function (response) {
			hookScriptMessage.text(translations.hookScriptSaved);
			hookScriptMessage.css('color', 'green');
			hookScriptMessage.show();
			setTimeout(function () {
				hookScriptMessage.hide();
				hookScriptModal.hide();
			}, 1000); // hide window in 1s
		}).fail(function () {
			hookScriptMessage.text(translations.hookScriptSaveFailed);
			hookScriptMessage.css('color', 'red');
			hookScriptMessage.show();
		});
	});
	$('#hook-script-cancel-btn').click(function () {
		hookScriptModal.hide();
	});
	function adjustTextareaHeight() {
		hookScriptTextarea.height(0);
		var height = hookScriptTextarea[0].scrollHeight;
		hookScriptTextarea.height(height);
	}
	hookScriptTextarea.on('input', adjustTextareaHeight);
});
