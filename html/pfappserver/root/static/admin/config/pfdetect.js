
$(function() { // DOM ready
    var items = new Pfdetects();
    var view = new PfdetectView({ items: items, parent: $('#section') });
});

/*
 * The Pfdetects class defines the operations available from the controller.
 */
var Pfdetects = function() {
};

Pfdetects.prototype = new Items();

Pfdetects.prototype.id  = '#pfdetects';

Pfdetects.prototype.formName  = 'modalPfdetect';

Pfdetects.prototype.modalId   = '#modalPfdetect';

/*
 * The PfdetectView class defines the DOM operations from the Web interface.
 */


var PfdetectView = function(options) {
    ItemView.call(this, options);
    var that = this;
    this.parent = options.parent;
    var items = options.items
    this.items = items;
    var id = items.id;
    var formName = items.formName;
    options.parent.off('click', id + ' [href$="/clone"]');

};

PfdetectView.prototype = (function(){
    function F(){};
    F.prototype = ItemView.prototype;
    return new F();
})();

PfdetectView.prototype.constructor = PfdetectView;

PfdetectView.prototype.toggleTaggedVlan = function(e) {
    var checkbox = $(this);
    var taggedVlan = checkbox.closest('form').find('input[name="taggedVlan"]').first();

    if (checkbox.is(':checked'))
        taggedVlan.removeAttr('disabled');
    else
        taggedVlan.attr('disabled', 1);
};

PfdetectView.prototype.updateItem = function(e) {
    e.preventDefault();

    var that = this;
    var form = $(e.target);
    var table = $(this.items.id);
    var section = $('#section');
    var btn = form.find('.btn-primary');
    var valid = isFormValid(form);
    if (valid) {
        btn.button('loading');
        this.items.post({
            url: form.attr('action'),
            data: form.serialize(),
            always: function() {
                // Restore hidden/template rows
                btn.button('reset');
            },
            success: function(data) {
                showSuccess(section.find('h2').first(), data.status_msg);
            },
            errorSibling: section.find('h2').first()
        });
    }
};


function submitFormGoToLocation(form) {
    $.ajax({
        'async' : false,
        'url'   : form.attr('action'),
        'type'  : form.attr('method') || "POST",
        'data'  : form.serialize()
        })
        .done(function(data, textStatus, jqXHR) {
            location.hash = jqXHR.getResponseHeader('Location');
        })
        .fail(function(jqXHR) {
            $("body,html").animate({scrollTop:0}, 'fast');
            var status_msg = getStatusMsg(jqXHR);
            showError($('#section h2'), status_msg);
        });
}

