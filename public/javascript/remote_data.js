var app = {};

app.RemoteData = Backbone.Model.extend({
  urlRoot: "/api/remote_data",
  defaults: {
    name: '',
    value: 0,
    address: 0
  }
});

app.RemoteDataView = Backbone.View.extend({
  tagName: "li",
  template: _.template('<label><%= name %></label><input type="range" min="0" max="1023" value="<%= value %>" />'),
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
    app.remote_data_list.fetch();
  },
  addOne: function(remote_data){
    var view = new app.RemoteDataView({model: remote_data});
    $('#remote-data').append(view.render().el);
  },
  addAll: function(){
    this.$('#remote-data').html(''); // clean the todo list
    app.remote_data_list.each(this.addOne, this);
  }
});
