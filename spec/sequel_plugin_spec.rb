require File.join(File.dirname(File.expand_path(__FILE__)), 'spec_helper.rb')

require 'rubygems'
require 'sequel'

DB = Sequel.sqlite
Sequel.default_timezone = :utc
DB.create_table(:artists) do
  primary_key :id
  String :name
end
DB.create_table(:albums) do
  primary_key :id
  foreign_key :artist_id, :artists
  String :name
  TrueClass :gold
  TrueClass :platinum, :null=>false, :default=>false
  Date :release_date
  DateTime :created_at
  Integer :copies_sold
end
DB.create_table(:album_infos) do
  primary_key :id
  foreign_key :album_id, :albums
  String :info
end
DB.create_table(:tracks) do
  primary_key :id
  foreign_key :album_id, :albums
  String :name
end
DB.create_table(:tags) do
  primary_key :id
  String :name
end
DB.create_table(:albums_tags) do
  foreign_key :album_id, :albums
  foreign_key :tag_id, :tags
end

a = DB[:artists].insert(:name=>'a')
d = DB[:artists].insert(:name=>'d')
b = DB[:albums].insert(:name=>'b', :artist_id=>a, :gold=>false, :release_date=>Date.new(2011, 6, 5), :created_at=>Date.new(2011, 6, 5), :copies_sold=>10)
DB[:tracks].insert(:name=>'m', :album_id=>b)
DB[:tracks].insert(:name=>'n', :album_id=>b)
c = DB[:albums].insert(:name=>'c', :artist_id=>d, :gold=>true, :platinum=>true)
DB[:tracks].insert(:name=>'o', :album_id=>c)
s = DB[:tags].insert(:name=>'s')
t = DB[:tags].insert(:name=>'t')
u = DB[:tags].insert(:name=>'u')
[[b, s], [b, t], [c, t]].each{|k, v| DB[:albums_tags].insert(k, v)}

Sequel::Model.plugin :forme
class Album < Sequel::Model
  many_to_one :artist, :order=>:name
  one_to_one :album_info
  one_to_many :tracks
  many_to_many :tags

  def artist_name
    artist.name if artist
  end
end
class Artist < Sequel::Model
  one_to_many :albums
  def idname() "#{id}#{name}" end
end
class Track < Sequel::Model; end
class Tag < Sequel::Model; end
class AlbumInfo < Sequel::Model; end

describe "Forme Sequel::Model forms" do
  before do
    @ab = Album[b]
    @b = Forme::Form.new(@ab)
    @ac = Album[c]
    @c = Forme::Form.new(@ac)
  end
  
  specify "should add appropriate attributes by default" do
    @b.form.to_s.should == '<form class="forme album" method="post"></form>'
  end

  specify "should allow overriding of attributes" do
    @b.form(:class=>:foo, :method=>:get).to_s.should == '<form class="foo forme album" method="get"></form>'
  end

  specify "should use a text field for strings" do
    @b.input(:name).to_s.should == '<label>Name: <input id="album_name" name="album[name]" type="text" value="b"/></label>'
    @c.input(:name).to_s.should == '<label>Name: <input id="album_name" name="album[name]" type="text" value="c"/></label>'
  end
  
  specify "should allow :as=>:textarea to use a textarea" do
    @b.input(:name, :as=>:textarea).to_s.should == '<label>Name: <textarea id="album_name" name="album[name]">b</textarea></label>'
    @c.input(:name, :as=>:textarea).to_s.should == '<label>Name: <textarea id="album_name" name="album[name]">c</textarea></label>'
  end
  
  specify "should use number inputs for integers" do
    @b.input(:copies_sold).to_s.should == '<label>Copies sold: <input id="album_copies_sold" name="album[copies_sold]" type="number" value="10"/></label>'
  end

  specify "should use date inputs for Dates" do
    @b.input(:release_date).to_s.should == '<label>Release date: <input id="album_release_date" name="album[release_date]" type="date" value="2011-06-05"/></label>'
  end
  
  specify "should use datetime inputs for Time" do
    @b.input(:created_at).to_s.should =~ %r{<label>Created at: <input id="album_created_at" name="album\[created_at\]" type="datetime" value="2011-06-05 00:00:00(GMT|UTC)"/></label>}
  end
  
  specify "should use datetime inputs for DateTimes" do
    @ab.values[:created_at] = DateTime.new(2011, 6, 5)
    @b.input(:created_at).to_s.should == '<label>Created at: <input id="album_created_at" name="album[created_at]" type="datetime" value="2011-06-05 00:00:00+00:00"/></label>'
  end

  specify "should include type as wrapper class" do
    @ab.values[:created_at] = DateTime.new(2011, 6, 5)
    f = Forme::Form.new(@ab, :wrapper=>:li)
    f.input(:name).to_s.should == '<li class="string"><label>Name: <input id="album_name" name="album[name]" type="text" value="b"/></label></li>'
    f.input(:release_date).to_s.should == '<li class="date"><label>Release date: <input id="album_release_date" name="album[release_date]" type="date" value="2011-06-05"/></label></li>'
    f.input(:created_at).to_s.should == '<li class="datetime"><label>Created at: <input id="album_created_at" name="album[created_at]" type="datetime" value="2011-06-05 00:00:00+00:00"/></label></li>'
  end
  
  specify "should include required wrapper class if required" do
    f = Forme::Form.new(@ab, :wrapper=>:li)
    f.input(:name, :required=>true).to_s.should == '<li class="string required"><label>Name: <input id="album_name" name="album[name]" required="required" type="text" value="b"/></label></li>'
  end
  
  specify "should use a select box for tri-valued boolean fields" do
    @b.input(:gold).to_s.should == '<label>Gold: <select id="album_gold" name="album[gold]"><option value=""></option><option value="t">True</option><option selected="selected" value="f">False</option></select></label>'
    @c.input(:gold).to_s.should == '<label>Gold: <select id="album_gold" name="album[gold]"><option value=""></option><option selected="selected" value="t">True</option><option value="f">False</option></select></label>'
  end
  
  specify "should use a checkbox for dual-valued boolean fields" do
    @b.input(:platinum).to_s.should == '<label><input id="album_platinum_hidden" name="album[platinum]" type="hidden" value="f"/><input id="album_platinum" name="album[platinum]" type="checkbox" value="t"/> Platinum</label>'
    @c.input(:platinum).to_s.should == '<label><input id="album_platinum_hidden" name="album[platinum]" type="hidden" value="f"/><input checked="checked" id="album_platinum" name="album[platinum]" type="checkbox" value="t"/> Platinum</label>'
  end
  
  specify "should use a select box for many_to_one associations" do
    @b.input(:artist).to_s.should == '<label>Artist: <select id="album_artist_id" name="album[artist_id]"><option value=""></option><option selected="selected" value="1">a</option><option value="2">d</option></select></label>'
    @c.input(:artist).to_s.should == '<label>Artist: <select id="album_artist_id" name="album[artist_id]"><option value=""></option><option value="1">a</option><option selected="selected" value="2">d</option></select></label>'
  end

  specify "should use a required wrapper tag for many_to_one required associations" do
    @b.input(:artist, :required=>true, :wrapper=>:li).to_s.should == '<li class="many_to_one required"><label>Artist: <select id="album_artist_id" name="album[artist_id]" required="required"><option value=""></option><option selected="selected" value="1">a</option><option value="2">d</option></select></label></li>'
  end

  specify "should use a set of radio buttons for many_to_one associations with :as=>:radio option" do
    @b.input(:artist, :as=>:radio).to_s.should == 'Artist: <label><input checked="checked" name="album[artist_id]" type="radio" value="1"/> a</label><label><input name="album[artist_id]" type="radio" value="2"/> d</label>'
    @c.input(:artist, :as=>:radio).to_s.should == 'Artist: <label><input name="album[artist_id]" type="radio" value="1"/> a</label><label><input checked="checked" name="album[artist_id]" type="radio" value="2"/> d</label>'
  end
  
  specify "should correctly use the forms wrapper for wrapping radio buttons for many_to_one associations with :as=>:radio option" do
    @b = Forme::Form.new(@ab, :wrapper=>:li)
    @b.input(:artist, :as=>:radio).to_s.should == '<li class="many_to_one">Artist: <label><input checked="checked" name="album[artist_id]" type="radio" value="1"/> a</label><label><input name="album[artist_id]" type="radio" value="2"/> d</label></li>'
  end
  
  specify "should support custom wrappers for many_to_one associations with :as=>:radio via :tag_wrapper option" do
    @b = Forme::Form.new(@ab, :wrapper=>:li)
    @b.input(:artist, :as=>:radio, :wrapper=>proc{|t, i| i.tag(:div, {}, [t])}, :tag_wrapper=>proc{|t, i| i.tag(:span, {}, [t])}).to_s.should == '<div>Artist: <span><label><input checked="checked" name="album[artist_id]" type="radio" value="1"/> a</label></span><span><label><input name="album[artist_id]" type="radio" value="2"/> d</label></span></div>'
  end
  
  specify "should respect an :options entry" do
    @b.input(:artist, :options=>Artist.order(:name).map{|a| [a.name, a.id+1]}).to_s.should == '<label>Artist: <select id="album_artist_id" name="album[artist_id]"><option value=""></option><option value="2">a</option><option value="3">d</option></select></label>'
    @c.input(:artist, :options=>Artist.order(:name).map{|a| [a.name, a.id+1]}).to_s.should == '<label>Artist: <select id="album_artist_id" name="album[artist_id]"><option value=""></option><option selected="selected" value="2">a</option><option value="3">d</option></select></label>'
  end
  
  specify "should support :name_method option for choosing name method" do
    @b.input(:artist, :name_method=>:idname).to_s.should == '<label>Artist: <select id="album_artist_id" name="album[artist_id]"><option value=""></option><option selected="selected" value="1">1a</option><option value="2">2d</option></select></label>'
    @c.input(:artist, :name_method=>:idname).to_s.should == '<label>Artist: <select id="album_artist_id" name="album[artist_id]"><option value=""></option><option value="1">1a</option><option selected="selected" value="2">2d</option></select></label>'
  end
  
  specify "should try a list of methods to get a suitable one for select box naming" do
    al = Class.new(Album){def self.name() 'Album' end}
    ar = Class.new(Artist)
    al.many_to_one :artist, :class=>ar
    ar.class_eval{undef_method(:name)}
    f = Forme::Form.new(al.new)

    ar.class_eval{def number() "#{self[:name]}1" end}
    f.input(:artist).to_s.should == '<label>Artist: <select id="album_artist_id" name="album[artist_id]"><option value=""></option><option value="1">a1</option><option value="2">d1</option></select></label>'

    ar.class_eval{def title() "#{self[:name]}2" end}
    f.input(:artist).to_s.should == '<label>Artist: <select id="album_artist_id" name="album[artist_id]"><option value=""></option><option value="1">a2</option><option value="2">d2</option></select></label>'

    ar.class_eval{def name() "#{self[:name]}3" end}
    f.input(:artist).to_s.should == '<label>Artist: <select id="album_artist_id" name="album[artist_id]"><option value=""></option><option value="1">a3</option><option value="2">d3</option></select></label>'

    ar.class_eval{def forme_name() "#{self[:name]}4" end}
    f.input(:artist).to_s.should == '<label>Artist: <select id="album_artist_id" name="album[artist_id]"><option value=""></option><option value="1">a4</option><option value="2">d4</option></select></label>'
  end
  
  specify "should raise an error when using an association without a usable name method" do
    al = Class.new(Album)
    ar = Class.new(Artist)
    al.many_to_one :artist, :class=>ar
    ar.class_eval{undef_method(:name)}
    proc{Forme::Form.new(al.new).input(:artist)}.should raise_error(Forme::Error)
  end
    
  specify "should use a multiple select box for one_to_many associations" do
    @b.input(:tracks).to_s.should == '<label>Tracks: <select id="album_track_pks" multiple="multiple" name="album[track_pks][]"><option selected="selected" value="1">m</option><option selected="selected" value="2">n</option><option value="3">o</option></select></label>'
    @c.input(:tracks).to_s.should == '<label>Tracks: <select id="album_track_pks" multiple="multiple" name="album[track_pks][]"><option value="1">m</option><option value="2">n</option><option selected="selected" value="3">o</option></select></label>'
  end
  
  specify "should use a multiple select box for many_to_many associations" do
    @b.input(:tags).to_s.should == '<label>Tags: <select id="album_tag_pks" multiple="multiple" name="album[tag_pks][]"><option selected="selected" value="1">s</option><option selected="selected" value="2">t</option><option value="3">u</option></select></label>'
    @c.input(:tags).to_s.should == '<label>Tags: <select id="album_tag_pks" multiple="multiple" name="album[tag_pks][]"><option value="1">s</option><option selected="selected" value="2">t</option><option value="3">u</option></select></label>'
  end

  specify "should use multiple checkboxes for one_to_many associations if :as=>:checkbox" do
    @b.input(:tracks, :as=>:checkbox).to_s.should == 'Tracks: <label><input checked="checked" name="album[track_pks][]" type="checkbox" value="1"/> m</label><label><input checked="checked" name="album[track_pks][]" type="checkbox" value="2"/> n</label><label><input name="album[track_pks][]" type="checkbox" value="3"/> o</label>'
    @c.input(:tracks, :as=>:checkbox).to_s.should == 'Tracks: <label><input name="album[track_pks][]" type="checkbox" value="1"/> m</label><label><input name="album[track_pks][]" type="checkbox" value="2"/> n</label><label><input checked="checked" name="album[track_pks][]" type="checkbox" value="3"/> o</label>'
  end
  
  specify "should use multiple checkboxes for many_to_many associations if :as=>:checkbox" do
    @b.input(:tags, :as=>:checkbox).to_s.should == 'Tags: <label><input checked="checked" name="album[tag_pks][]" type="checkbox" value="1"/> s</label><label><input checked="checked" name="album[tag_pks][]" type="checkbox" value="2"/> t</label><label><input name="album[tag_pks][]" type="checkbox" value="3"/> u</label>'
    @c.input(:tags, :as=>:checkbox).to_s.should == 'Tags: <label><input name="album[tag_pks][]" type="checkbox" value="1"/> s</label><label><input checked="checked" name="album[tag_pks][]" type="checkbox" value="2"/> t</label><label><input name="album[tag_pks][]" type="checkbox" value="3"/> u</label>'
  end

  specify "should correctly use the forms wrapper for wrapping radio buttons for one_to_many associations with :as=>:checkbox option" do
    @b = Forme::Form.new(@ab, :wrapper=>:li)
    @b.input(:tracks, :as=>:checkbox).to_s.should == '<li class="one_to_many">Tracks: <label><input checked="checked" name="album[track_pks][]" type="checkbox" value="1"/> m</label><label><input checked="checked" name="album[track_pks][]" type="checkbox" value="2"/> n</label><label><input name="album[track_pks][]" type="checkbox" value="3"/> o</label></li>'
  end
  
  specify "should support custom wrappers for one_to_many associations with :as=>:checkbox via :tag_wrapper option" do
    @b = Forme::Form.new(@ab, :wrapper=>:li)
    @b.input(:tracks, :as=>:checkbox, :wrapper=>proc{|t, i| i.tag(:div, i.opts[:wrapper_attr], [t])}, :tag_wrapper=>proc{|t, i| i.tag(:span, {}, [t])}).to_s.should == '<div class="one_to_many">Tracks: <span><label><input checked="checked" name="album[track_pks][]" type="checkbox" value="1"/> m</label></span><span><label><input checked="checked" name="album[track_pks][]" type="checkbox" value="2"/> n</label></span><span><label><input name="album[track_pks][]" type="checkbox" value="3"/> o</label></span></div>'
  end
  
  specify "should use a text field methods not backed by columns" do
    @b.input(:artist_name).to_s.should == '<label>Artist name: <input id="album_artist_name" name="album[artist_name]" type="text" value="a"/></label>'
    @c.input(:artist_name).to_s.should == '<label>Artist name: <input id="album_artist_name" name="album[artist_name]" type="text" value="d"/></label>'
  end

  specify "should correctly show an error message if there is one" do
    @ab.errors.add(:name, 'tis not valid')
    @b.input(:name).to_s.should == '<label>Name: <input class="error" id="album_name" name="album[name]" type="text" value="b"/><span class="error_message">tis not valid</span></label>'
  end
  
  specify "should correctly show an error message for many_to_one associations if there is one" do
    @ab.errors.add(:artist_id, 'tis not valid')
    @b.input(:artist).to_s.should == '<label>Artist: <select class="error" id="album_artist_id" name="album[artist_id]"><option value=""></option><option selected="selected" value="1">a</option><option value="2">d</option></select><span class="error_message">tis not valid</span></label>'
  end
  
  specify "should raise an error for unhandled associations" do
    al = Class.new(Album)
    al.association_reflection(:tags)[:type] = :foo
    proc{Forme::Form.new(al.new).input(:tags)}.should raise_error(Forme::Error)
  end
  
  specify "should raise an error for unhandled fields" do
    proc{@b.input(:foo)}.should raise_error(Forme::Error)
  end

  specify "should add required attribute if the column doesn't support nil values" do
    def @ab.db_schema; h = super.dup; h[:name] = h[:name].merge(:allow_null=>false); h end
    @b.input(:name).to_s.should == '<label>Name: <input id="album_name" name="album[name]" required="required" type="text" value="b"/></label>'
  end
  
  specify "should use allow nested forms with many_to_one associations" do
    Forme.form(@ab){|f| f.subform(:artist){f.input(:name)}}.to_s.should == '<form class="forme album" method="post"><input id="album_artist_attributes_id" name="album[artist_attributes][id]" type="hidden" value="1"/><label>Name: <input id="album_artist_attributes_name" name="album[artist_attributes][name]" type="text" value="a"/></label></form>'
  end
  
  specify "should have #subform respect an :inputs option" do
    Forme.form(@ab){|f| f.subform(:artist, :inputs=>[:name])}.to_s.should == '<form class="forme album" method="post"><input id="album_artist_attributes_id" name="album[artist_attributes][id]" type="hidden" value="1"/><fieldset class="inputs"><legend>Artist</legend><label>Name: <input id="album_artist_attributes_name" name="album[artist_attributes][name]" type="text" value="a"/></label></fieldset></form>'
  end
  
  specify "should have #subform respect an :obj option overriding the object to use" do
    Forme.form(@ab){|f| f.subform(:artist, :inputs=>[:name], :obj=>Artist.new(:name=>'b'))}.to_s.should == '<form class="forme album" method="post"><fieldset class="inputs"><legend>Artist</legend><label>Name: <input id="album_artist_attributes_name" name="album[artist_attributes][name]" type="text" value="b"/></label></fieldset></form>'
  end
  
  specify "should have #subform respect a :legend option if :inputs is used" do
    Forme.form(@ab){|f| f.subform(:artist, :inputs=>[:name], :legend=>'Foo')}.to_s.should == '<form class="forme album" method="post"><input id="album_artist_attributes_id" name="album[artist_attributes][id]" type="hidden" value="1"/><fieldset class="inputs"><legend>Foo</legend><label>Name: <input id="album_artist_attributes_name" name="album[artist_attributes][name]" type="text" value="a"/></label></fieldset></form>'
  end
  
  specify "should have #subform respect a callable :legend option if :inputs is used" do
    Forme.form(@ab){|f| f.subform(:artist, :inputs=>[:name], :legend=>proc{|o| "Foo - #{o.name}"})}.to_s.should == '<form class="forme album" method="post"><input id="album_artist_attributes_id" name="album[artist_attributes][id]" type="hidden" value="1"/><fieldset class="inputs"><legend>Foo - a</legend><label>Name: <input id="album_artist_attributes_name" name="album[artist_attributes][name]" type="text" value="a"/></label></fieldset></form>'
  end
  
  specify "should not add hidden primary key field for new many_to_one associated objects" do
    @ab.associations[:artist] = Artist.new(:name=>'a')
    Forme.form(@ab){|f| f.subform(:artist){f.input(:name)}}.to_s.should == '<form class="forme album" method="post"><label>Name: <input id="album_artist_attributes_name" name="album[artist_attributes][name]" type="text" value="a"/></label></form>'
  end
  
  specify "should use allow nested forms with one_to_one associations" do
    Forme.form(@ab){|f| f.subform(:album_info, :obj=>AlbumInfo.new(:info=>'a')){f.input(:info)}}.to_s.should == '<form class="forme album" method="post"><label>Info: <input id="album_album_info_attributes_info" name="album[album_info_attributes][info]" type="text" value="a"/></label></form>'
  end
  
  specify "should use allow nested forms with one_to_many associations" do
    Forme.form(@ab){|f| f.subform(:tracks){f.input(:name)}}.to_s.should == '<form class="forme album" method="post"><input id="album_tracks_attributes_0_id" name="album[tracks_attributes][0][id]" type="hidden" value="1"/><label>Name: <input id="album_tracks_attributes_0_name" name="album[tracks_attributes][0][name]" type="text" value="m"/></label><input id="album_tracks_attributes_1_id" name="album[tracks_attributes][1][id]" type="hidden" value="2"/><label>Name: <input id="album_tracks_attributes_1_name" name="album[tracks_attributes][1][name]" type="text" value="n"/></label></form>'
  end
  
  specify "should support :obj option for *_to_many associations" do
    Forme.form(@ab){|f| f.subform(:tracks, :obj=>[Track.new(:name=>'x'), Track.load(:id=>5, :name=>'y')]){f.input(:name)}}.to_s.should == '<form class="forme album" method="post"><label>Name: <input id="album_tracks_attributes_0_name" name="album[tracks_attributes][0][name]" type="text" value="x"/></label><input id="album_tracks_attributes_1_id" name="album[tracks_attributes][1][id]" type="hidden" value="5"/><label>Name: <input id="album_tracks_attributes_1_name" name="album[tracks_attributes][1][name]" type="text" value="y"/></label></form>'
  end
  
  specify "should auto number legends when using subform with inputs for *_to_many associations" do
    Forme.form(@ab){|f| f.subform(:tracks, :inputs=>[:name])}.to_s.should == '<form class="forme album" method="post"><input id="album_tracks_attributes_0_id" name="album[tracks_attributes][0][id]" type="hidden" value="1"/><fieldset class="inputs"><legend>Track #1</legend><label>Name: <input id="album_tracks_attributes_0_name" name="album[tracks_attributes][0][name]" type="text" value="m"/></label></fieldset><input id="album_tracks_attributes_1_id" name="album[tracks_attributes][1][id]" type="hidden" value="2"/><fieldset class="inputs"><legend>Track #2</legend><label>Name: <input id="album_tracks_attributes_1_name" name="album[tracks_attributes][1][name]" type="text" value="n"/></label></fieldset></form>'
  end
  
  specify "should support callable :legend option when using subform with inputs for *_to_many associations" do
    Forme.form(@ab){|f| f.subform(:tracks, :inputs=>[:name], :legend=>proc{|o, i| "Track #{i} (#{o.name})"})}.to_s.should == '<form class="forme album" method="post"><input id="album_tracks_attributes_0_id" name="album[tracks_attributes][0][id]" type="hidden" value="1"/><fieldset class="inputs"><legend>Track 0 (m)</legend><label>Name: <input id="album_tracks_attributes_0_name" name="album[tracks_attributes][0][name]" type="text" value="m"/></label></fieldset><input id="album_tracks_attributes_1_id" name="album[tracks_attributes][1][id]" type="hidden" value="2"/><fieldset class="inputs"><legend>Track 1 (n)</legend><label>Name: <input id="album_tracks_attributes_1_name" name="album[tracks_attributes][1][name]" type="text" value="n"/></label></fieldset></form>'
  end
  
  specify "should not add hidden primary key field for nested forms with one_to_many associations" do
    @ab.associations[:tracks] = [Track.new(:name=>'m'), Track.new(:name=>'n')]
    Forme.form(@ab){|f| f.subform(:tracks){f.input(:name)}}.to_s.should == '<form class="forme album" method="post"><label>Name: <input id="album_tracks_attributes_0_name" name="album[tracks_attributes][0][name]" type="text" value="m"/></label><label>Name: <input id="album_tracks_attributes_1_name" name="album[tracks_attributes][1][name]" type="text" value="n"/></label></form>'
  end
  
  specify "should use allow nested forms with many_to_many associations" do
    Forme.form(@ab){|f| f.subform(:tags){f.input(:name)}}.to_s.should == '<form class="forme album" method="post"><input id="album_tags_attributes_0_id" name="album[tags_attributes][0][id]" type="hidden" value="1"/><label>Name: <input id="album_tags_attributes_0_name" name="album[tags_attributes][0][name]" type="text" value="s"/></label><input id="album_tags_attributes_1_id" name="album[tags_attributes][1][id]" type="hidden" value="2"/><label>Name: <input id="album_tags_attributes_1_name" name="album[tags_attributes][1][name]" type="text" value="t"/></label></form>'
  end
  
  specify "should not add hidden primary key field for nested forms with many_to_many associations" do
    @ab.associations[:tags] = [Tag.new(:name=>'s'), Tag.new(:name=>'t')]
    Forme.form(@ab){|f| f.subform(:tags){f.input(:name)}}.to_s.should == '<form class="forme album" method="post"><label>Name: <input id="album_tags_attributes_0_name" name="album[tags_attributes][0][name]" type="text" value="s"/></label><label>Name: <input id="album_tags_attributes_1_name" name="album[tags_attributes][1][name]" type="text" value="t"/></label></form>'
  end

  specify "should handle multiple nested levels" do
    Forme.form(Artist[1]){|f| f.subform(:albums){f.input(:name); f.subform(:tracks){f.input(:name)}}}.to_s.to_s.should == '<form class="forme artist" method="post"><input id="artist_albums_attributes_0_id" name="artist[albums_attributes][0][id]" type="hidden" value="1"/><label>Name: <input id="artist_albums_attributes_0_name" name="artist[albums_attributes][0][name]" type="text" value="b"/></label><input id="artist_albums_attributes_0_tracks_attributes_0_id" name="artist[albums_attributes][0][tracks_attributes][0][id]" type="hidden" value="1"/><label>Name: <input id="artist_albums_attributes_0_tracks_attributes_0_name" name="artist[albums_attributes][0][tracks_attributes][0][name]" type="text" value="m"/></label><input id="artist_albums_attributes_0_tracks_attributes_1_id" name="artist[albums_attributes][0][tracks_attributes][1][id]" type="hidden" value="2"/><label>Name: <input id="artist_albums_attributes_0_tracks_attributes_1_name" name="artist[albums_attributes][0][tracks_attributes][1][name]" type="text" value="n"/></label></form>'
  end
end

describe "Forme Sequel plugin default input types based on column names" do
  def f(name)
    DB.create_table!(:test){String name}
    Forme::Form.new(Class.new(Sequel::Model){def self.name; 'Test' end; set_dataset :test}.new).input(name, :value=>'foo')
  end

  specify "should use password input with no value for string columns with name password" do
    f(:password).to_s.should == '<label>Password: <input id="test_password" name="test[password]" type="password"/></label>'
  end

  specify "should use email input for string columns with name email" do
    f(:email).to_s.should == '<label>Email: <input id="test_email" name="test[email]" type="email" value="foo"/></label>'
  end

  specify "should use tel input for string columns with name phone or fax" do
    f(:phone).to_s.should == '<label>Phone: <input id="test_phone" name="test[phone]" type="tel" value="foo"/></label>'
    f(:fax).to_s.should == '<label>Fax: <input id="test_fax" name="test[fax]" type="tel" value="foo"/></label>'
  end

  specify "should use url input for string columns with name url, uri, or website" do
    f(:url).to_s.should == '<label>Url: <input id="test_url" name="test[url]" type="url" value="foo"/></label>'
    f(:uri).to_s.should == '<label>Uri: <input id="test_uri" name="test[uri]" type="url" value="foo"/></label>'
    f(:website).to_s.should == '<label>Website: <input id="test_website" name="test[website]" type="url" value="foo"/></label>'
  end
end 

describe "Forme Sequel plugin default input types based on column type" do
  def f(type)
    DB.create_table!(:test){column :foo, type}
    Forme::Form.new(Class.new(Sequel::Model){def self.name; 'Test' end; set_dataset :test}.new).input(:foo, :value=>'foo')
  end

  specify "should use password input with no value for string columns with name password" do
    f(File).to_s.should == '<label>Foo: <input id="test_foo" name="test[foo]" type="file"/></label>'
  end
end