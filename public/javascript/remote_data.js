var app = {};

app.RemoteData = Backbone.Model.extend({
  urlRoot: "/api/remote_data",
  defaults: {
    id: 0,
    name: '',
    value: 0,
    address: 0
  }
});

app.RemoteDataView = Backbone.View.extend({
  tagName: "section",
  template: _.template(
    '<div class="remote-data"> \
    <div class="range-slider vertical-range" data-slider data-options="vertical: true; start: 0; end: 1023; initial: <%= value %>;"> \
        <span class="range-slider-handle" role="slider" tabindex="0"></span> \
        <span class="range-slider-active-segment"></span> \
        <input type="hidden"> \
    </div> \
    <br /> \
    <label><%= name %></label> \
    </div>'
  ),
  render: function() {
    this.$el.html(this.template(this.model.toJSON()));
    return this;
  },
});

app.RemoteDataList = Backbone.Collection.extend({
  model: app.RemoteData,
  url: "/api/remote_data"
});

app.AppView = Backbone.View.extend({
  el: "#container",
  initialize: function(){
    app.remote_data_list = new app.RemoteDataList();
    app.remote_data_list.on('add', this.addOne, this);
    app.remote_data_list.on('reset', this.addAll, this);
    app.remote_data_list.on('sync', this.addAll, this);
    app.remote_data_list.fetch();
  },
  addOne: function(remote_data){
    var view = new app.RemoteDataView({model: remote_data});
    $('#remote-data').append(view.render().el);
    $(document).foundation('slider', 'reflow');
  },
  addAll: function(){
    this.$('#remote-data').html(''); // clean the todo list
    app.remote_data_list.each(this.addOne, this);
  },
  render: function(){
    this.$el.html = "";
    this.addAll();
  }
});
