# Title: Advanced Music Player
# Author: Aiden Mellor
# Version: 1.3

############################
      # XML Example #
############################

=begin
<?xml version="1.0"?>
<root>
    <album> 
        <name>Greatest Hits</name>
        <genre>Rock</genre>
        <artist>Niel Diamond</artist>
        <cover>./Covers/NielDiamond.jpg</cover>
        <songs>
            <song>
                <name>Crackling Rose</name>
                <location>Music/Cracklin_Rose.wav</location>
            </song>
            <song>
                <name>Soolaimon</name>
                <location>Music/Soolaimon.wav</location>
            </song>
            <song>
                <name>Sweet Caroline</name>
                <location>Music/Sweet_Caroline.wav</location>
            </song>
        </songs>
    </album>
</root>
=end

############################
    # Global Settings #
############################

# Possible Neat File Seperation
# require './events.rb'
# require './functions.rb'
# require './classes.rb'

# Ruby gem imports (gem install *name*)
require 'gosu' # Basic Game Engine
require 'colorize' # Console Colouring
require 'nokogiri' # XML File reading
require 'waveinfo' # WAV File reading

WIDTH = 1920 / 2
HEIGHT = 1080 / 2

DEBUG = FALSE #Enable to Display Console Statistics

BACK,MIDDLE,TOP,PLAYBAR,BUTTONS = *0..4
ELEMENT,FONT,IMAGE = *0..2

# Colour Palette Variables
PRIMARY = Gosu::Color.argb(255, 26, 26, 26)
SECONDARY = Gosu::Color.argb(255, 33, 33, 33)
TIERTARY = Gosu::Color.argb(255, 85, 85, 85)
HIGHLIGHT = Gosu::Color.argb(255, 106, 121, 255)
TEXT = Gosu::Color.argb(255, 132, 132, 132)
WHITE_TEXT = Gosu::Color.argb(255, 255, 255, 255)
IMAGE_COLOR = Gosu::Color.argb(255, 255, 255, 255)
OVERLAY = Gosu::Color.argb(50, 255, 255, 255)
SONGS = Gosu::Color.argb(100, 26, 26, 26)
PROGRESS_BAR = Gosu::Color.argb(255, 106 - 25, 121 - 25, 255 - 25)

############################
        # Classes #
############################

# All Attribute Accesor data storing classes
class Element
    attr_accessor :x, :y, :width, :height, :colour, :z, :name
    def initialize(x, y, width, height, colour, z, name)
        @name = name
        @x = x
        @y = y
        @width = width
        @height = height
        @colour = colour
        @z = z
    end
end

class Image
    attr_accessor :x, :y, :width, :height, :colour, :z, :name, :path
    def initialize(x, y, width, height, colour, z, name, path)
        @name = name
        @x = x
        @y = y
        @width = width
        @height = height
        @colour = colour
        @z = z
        @path = path
    end
end

class Font
    attr_accessor :x, :y, :z, :size, :colour, :name, :text
    def initialize(x, y, z, size, colour, name, text)
        @size = size
        @name = name
        @x = x
        @y = y
        @z = z
        @colour = colour
        @text = text
    end
end

# Stores all nessisary particle data
class Particle
    attr_accessor :x, :y, :size, :direction_x, :direction_y, :r, :g, :b, :t
    def initialize(x,y,size,direction_x,direction_y,r,g,b,t)
        @x = x
        @y = y
        @size = size
        @direction_x = direction_x
        @direction_y = direction_y
        @r = r
        @g = g
        @b = b
        @t = t
    end
end

# Song and Album classes store data in from
# the player_data xml file
class Song
	attr_accessor :name, :location
	def initialize (name, location)
		@name = name
		@location = location
	end
end

class Album
	attr_accessor :title, :artist, :genre, :songs, :cover
	def initialize (title, artist, genre, songs, cover)
		@title = title
		@artist = artist
		@genre = genre
        @songs = songs
        @cover = cover
	end
end

############################
        # Events #
############################

# function takes in the currently hovered over
# element then can apply or change any of the
# elements attribute settings
def hover_event(element)
    # replaces element colour with overlay only
    # while mouse over
   element.colour = OVERLAY
end

# Handles all elements that have been clicked
# on that contain the phrase "button" within
# it's name string then sorts them by their
# button group. Button name syntax structure:
#
# button name: [panel_group]_button_[button_unique_index]
#
def click_event(element)
   
   DEBUG ? (puts "Clicked on #{element.name}") : nil

   # Checks if element name starts
   # With the included string
   if element.name["album_button"]
       # Splits up element name then grabs the ending integer
       album_ID = element.name.split("_")[2].to_i
       DEBUG ? (puts "Album ID : #{album_ID.to_i}") : nil
       # Sets current clicked on album to button integer
       @selected_album = album_ID.to_i
   end

   if element.name["song_button"]
       song_ID = element.name.split("_")[2].to_i
       play_song(song_ID)
   end

   if element.name["scroll_button"]
       scroll_ID = element.name.split("_")[2].to_i
       case scroll_ID
       when 0 #up
           @page -= 1
       when 1 #down
           @page += 1
       end
   end

   if element.name["play_button"]
       play_ID = element.name.split("_")[2].to_i
       case play_ID
       when 0 # Repeat
           @repeat_song ? @repeat_song = false : @repeat_song = true
           puts "Repeat = " + @repeat_song.to_s.blue
       when 1 # Forward
           play_song(@currently_playing + 1)
       when 2 # Pause
           particle_burst(20,2,3)
           if @pause_play == "pause"
               @pause_play = "play"
               @song_settings.pause
           else
               @pause_play = "pause"
               @song_settings.resume
           end
       when 3 # Backward
           play_song(@currently_playing - 1)
       when 4 # Stop
           stop_song()
       end
   end
end

############################
       # Functions #
############################

# truncate function takes a string and
# max character then cuts it to set size
# then adds ... to end of string
def truncate(string, max)
    return string.size > max ? "#{string[0...max]}..." : string
end

# load_image safely loads in an image
# so that the program doesn't crash
def load_image(path)
    begin
        return Gosu::Image.new(path)
      rescue
        return Gosu::Image.new("images/error.png") rescue nil
    end
end

# takes in an images set size and 
# then it's prefered size and converts
# it into a 1.0 scale value
def img_size(image_size, new_size)
  decrease = new_size.fdiv(image_size)
  return decrease
end

# Fully clears console
def clear_console()
    puts "\e[H\e[2J"
end

# Handles all inputed or added elements
# then sorts them into array
def add_element(type,*args)
  # Case statement sorts elements by type
  # in order to align it to it's correct
  # class then add it to @elements array
  case type
  when ELEMENT
    # Element Argument Structure:
    # (type, x, y, width, height, colour, z, name)
    @elements << Element.new(*args)
  when IMAGE
    # Image Argument Structure:
    # (type, x, y, width, height, colour, z, name, file_path)
    @elements << Image.new(*args)
  when FONT
    # Element Argument Structure:
    # (type, x, y, z, size, colour, name, text)
    @elements << Font.new(*args)
  end
end

# Takes each element from @elements array
# containing all of the element class types
# then sorts them into each class type and
# appropriatly draws out each element from
# the class attributes array stored data
def draw_elements()
  for element in @elements do
      case element.class.name
      when "Element"
        draw_rect(element.x,element.y,element.width,element.height,element.colour,element.z)
      when "Image"
          img = load_image(element.path) # Safely Loads in image from file path
          # Uses img_size to convert size to 1.0 size scaling
          img.draw_rot(element.x,element.y,10,0,0,0,img_size(img.width,element.width),img_size(img.height,element.height),element.colour)
      when "Font"
          @info_font.draw_text_rel(element.text,element.x,element.y,element.z,0,0,element.size,element.size,element.colour)
      end
  end
end

# Runs through all of the elements within the
# @elements class array then outputs the element
# that the mouse's x and y are currently over
def iterate_element()
  for element in @elements do
      if element.class.name != "Font" && element.name.include?("button") # Checks if it's a button type
        if mouse_x.between?(element.x,element.x + element.width) and mouse_y.between?(element.y,element.y + element.height)
            return element
        end
      end
  end
  return nil # fall back
end

# Reads in a XML file then adds appropriate
# data into classes and the outputs an array
# with all included class data
def read_album(data)

  # Assigns XML file path arrays to appropriate
  # variables and if fails then assign empty array
	album_names = data.xpath("//album/name") rescue album_names = []
	album_artist = data.xpath("//album/artist") rescue album_artist = []
  album_genre = data.xpath("//album/genre") rescue album_genre = []
  album_cover = data.xpath("//album/cover") rescue album_cover = []
	
	album_array = Array.new # Temp function array for returning
	i = 0
  while i < album_names.size	
    # Iterates through albums in xml file	
		album_songs = data.xpath("//album[#{i+1}]/songs/song/name")
		album_songs_dir = data.xpath("//album[#{i+1}]/songs/song/location")
		song = 0
    song_array = Array.new
    # Iterates through all albumssongs and
    # stores an array of song classes within
    # the album classes songs attribute
		while song < album_songs.size
			song_array << Song.new(album_songs[song].text,album_songs_dir[song].text)
			song += 1
		end
		album_array << Album.new(album_names[i].text,album_artist[i].text,album_genre[i].text,song_array,album_cover[i])
		i += 1
	end
	return album_array
end

# Handles playing a song based off of an inputed index
# which related to @data_arrays contained class info
# from the read xml file
def play_song(id)
  @pause_play = "pause" # Resets pause button
  @song_settings.stop rescue nil # Makes sure no other song is playing
  begin
    path = @data_array[@selected_album].songs[id.to_i].location
    wave = WaveInfo.new(path) # Uses wave info gem to grab info from wav
    @song_length = wave.duration # Broadcasts song duration
    @tick = Gosu.milliseconds # Resets ticker so that @count_up starts at 0
    @currently_playing = id # Broadcasts currently playing song
    @playing_album_name = @data_array[@selected_album].title.upcase
    @playing_song_name = @data_array[@selected_album].songs[id].name.upcase
    @playing_thumbnail = @data_array[@selected_album].cover
    song = Gosu::Sample.new(path) # Sample plays wav file from path
    @song_settings = song.play(100,1,false)
    @show_playbar = true
  rescue
    @show_player = false
    stop_song()
    puts "SONG WAS NOT FOUND".red
  end
end

# Handles events surrounding the stopping
# of the currently playinh song
def stop_song()
  @song_settings.stop rescue nil
  @show_playbar = false
end

# Uses the nokogiri xml builder to create 
# structred xml based of of all the songs
# within each album
def create_all_songs()
  File.open("all_songs.xml", "w+") 
  builder = Nokogiri::XML::Builder.new do |xml| xml.root {
    for album in @data_array do
      for song in album.songs do
            xml.song {
              xml.name song.name
              xml.location song.location
              xml.genre album.genre
              xml.artist album.artist
            }
        end
      end
  }
  end
  File.write("all_songs.xml", builder.to_xml)
end

# Function focusses on drawing out each individual particle
# stored within the @particles instance array as well as
# adding motion to the particle since this function is contained
# within the update method
def draw_particles()
  for particle in @particles do
    colour_fade = Gosu::Color.argb(particle.t -= 5, particle.r, particle.g, particle.b)
    draw_rect(particle.x += particle.direction_x,particle.y += particle.direction_y,particle.size,particle.size,colour_fade,10)
    
    # Removes particle from array therefore
    # preventing it from being redrawn after it's
    # transparecy is below 0 improving performance
    # and indefinite particle array growth
    if particle.t <= 0
      @particles.delete(particle)
    end
  end
end

# Contains initialization data for each particle and
# controls the amount, size and speed
def particle_burst(amount, size, speed)
  # Randomize Colour
  # r = rand(0..255)
  # g = rand(0..255)
  # b = rand(0..255)
  # Morph Colour
  # @morph += 5
  # @morph >= 255 ? (@morph = 0) : nil
  # Statoc Colour
  r = 255
  g = 255
  b = 255

  # Removes 0 from set of possible speeds in order
  # to prevent particles from having no motion
  rand_x = [*-speed..speed] - [0]
  rand_y = [*-speed..speed] - [0]
  DEBUG ? (puts "#{rand_x} : #{rand_y}") : nil
  amount.times do
    @particles << Particle.new(mouse_x,mouse_y,size,rand_x.sample,rand_y.sample,r,g,b,255)
  end
end

############################
   # Gosu Functionailty #
############################

class Window < Gosu::Window

    def initialize
        super WIDTH, HEIGHT

        # Class Arrays
        @elements = Array.new
        @album_array = Array.new
        @particles = Array.new

        # Nokogiri loads in xml files and enables reading and writting
        File.file?("player_data.xml") ? file = File.open("player_data.xml", "r+") : file = File.open("player_data.xml", "w+") 
        @data = Nokogiri::XML(file)

        # General Initialization variables
        @progress = 0
        @pause_play = "pause"
        @info_font = Gosu::Font.new(20)
        @data_array = read_album(@data) # Reads in all data from xml file
        @selected_album = 0
        @repeat_song = false
        @show_playbar = false
        @song_length = nil
        @currently_playing = nil
        @playing_album_name = nil
        @playing_song_name = nil
        @playing_thumbnail = nil
        @morph = 0
        @viewable_albums = 7
        @page = 0
        @tick = Gosu.milliseconds

        # Creates an XML files with songs from all albums
        create_all_songs()
    end

    # Tells gosu that the cursor can be shown when hovering
    # Over the program window
    def needs_cursor?
        true
    end

    # Finds the current element the mouse is over and
    # passes it into click_event which handles button
    # functionallity
    def button_up(id)
        case id
        when Gosu::MsLeft
            if iterate_element() != nil
                element = iterate_element()
                click_event(element)
            end
        end
    end

    def update
        # Loads all rect, font and image data and stores
        # them into an array. All maths and loops are
        # iterated all within this function.
        initialize_elements()

        # Finds current element that the mouse is over
        # then passes it through hover_event to constantly
        # handle element highlighting / hover functionality
        if iterate_element() != nil
            element = iterate_element()
            hover_event(element)
        end

        # Sets window title
        self.caption = "Music Player [FPS: #{Gosu::fps.to_s}]"
    end

    def draw
        # Iterates through the elements array and draws out
        # every element from it's class attribute asscessor
        # data
        draw_elements()

        # Draws any particle classes that are currently present
        # within the instance variable array
        draw_particles()
    end
end

def initialize_elements
    @elements = Array.new # Cleans array each frame to prevent element duplication
    @viewable_albums = 7  # Sets amount of possible viewable albums to prevent ui overlap
    if @show_playbar
        @viewable_albums = 6 # Scales result for when bar is visible
        start_playbar()
        draw_play_bar()
    end
    draw_album_bar()
    draw_song_panel()
end

# Handles all of the song progress bar functionality
# Using gosu's in-built millisecond counter to track
# track running time
def start_playbar
    if @pause_play == "pause"
        @count_up = (Gosu.milliseconds - @tick)
        seconds = @count_up / 1000
        @progress = seconds * WIDTH / @song_length # Fits relative progress to window width

        # Statements handle song repeating and or next
        # track functionality
        if seconds >= @song_length.to_i && @repeat_song
            play_song(@currently_playing)
        elsif seconds >= @song_length.to_i
            play_song(@currently_playing + 1)
        end
    else
        @tick = Gosu.milliseconds - @count_up # pauses counter at current time
    end
end

# Handles visual maths and song button creation
def draw_song_panel
    margin = 10
    titles = ["NAME", "ARTIST", "GENRE", "RELEASE"] # Array contains space out titles
    add_element(ELEMENT,0,0,WIDTH,HEIGHT,SECONDARY,BACK,"rect_song_background")
    add_element(FONT,200 + margin,margin,PLAYBAR,1,HIGHLIGHT,"txt_songs","SONGS")

    shift = 0
    for title in titles
        add_element(FONT,200 + margin + shift,@info_font.height + margin,PLAYBAR,0.7,TEXT,"txt_title",title)
        shift += 200 #Controls Spacing between each title
    end
    draw_songs()
end

# Creates all possible song titles
def draw_songs
    i = 0
    spacing = 0
    # grabs album song data from data array aswell as the
    # currently selected album index
    while i < @data_array[@selected_album].songs.length
        draw_song(spacing,i)
        i += 1
        spacing += (40 + 5)
    end
end

# Handles drawing a singular song to the songs panel
# the y input controls the distance offset between each
# panel while i is the passed array index
def draw_song(y,i)
    margin = 20
    album = @data_array[@selected_album]
    song_info = [album.songs[i].name, album.artist, album.genre, "Unknown"]
    add_element(ELEMENT,200,margin + 40 + y,WIDTH,(margin * 2),SONGS,MIDDLE, "song_button_#{i}")
    shift = 0
    for info in song_info
        add_element(FONT,200 + margin + shift,margin + 50 + y,PLAYBAR,0.7,WHITE_TEXT,"txt_songs",info)
        shift += 200
    end
end

# Adds and calculates album bar basic positions
def draw_album_bar
    bar_width = 200
    margin = 15
    box_height = 50
    add_element(ELEMENT,0,0,bar_width,HEIGHT,PRIMARY,MIDDLE, "rect_album_background")

    # If statements determine the current page number using
    # a instance variable to shift viewable elements out and in
    # of the defined amount of viewable albums
    if !(@page <= 0)
        add_element(ELEMENT,0,0,bar_width,25,HIGHLIGHT,MIDDLE,"scroll_button_0")
    end
    if !(@page + @viewable_albums >= @data_array.size)
        # Helps scale button positioning to work around the playbar
        # and prevent the UI overlapping
        @show_playbar ? offset = 100 : offset = 25 
        add_element(ELEMENT,0,HEIGHT - offset,bar_width,25,HIGHLIGHT,MIDDLE,"scroll_button_1")
    end
    display_albums(margin, box_height, bar_width)
end

# Works on displaying multiple albums using a iteration
# while loop keeping regards to the viewable albums and
# current page
def display_albums(margin, box_height, bar_width)
    spacing = 0
    spacing_add = box_height + margin
    i = @page
    while i < @viewable_albums + @page
        display_album(@data_array[i].title, spacing, box_height, margin, bar_width, PRIMARY, "album_button_#{i}",i) rescue nil
        spacing += spacing_add
        i += 1
    end
end

# Will work on displaying a single album complimenting
# the display_albums function
def display_album(name, spacing, box_height, margin, bar_width, color, button_name,i)
    box_width = bar_width - (margin * 2)
    font_size = 15
    top_seperator = 25
    name = truncate(name, 20)
    
    add_element(ELEMENT,margin,top_seperator + margin + spacing,box_width,box_height,color,TOP,button_name)
    add_element(FONT,margin + box_height + 10,top_seperator + (margin + (box_height / 2) - (font_size / 2)) + spacing,TOP,0.7,TEXT,"txt_album_name",name)
    add_element(IMAGE,margin,top_seperator + margin + spacing,box_height,box_height,IMAGE_COLOR,TOP,"img_album_thumbnail",@data_array[i].cover)
end

def draw_play_bar()

    # Basic Playbar Settings
    playbar_height = 75
    progress = @progress
    scale = 0.5
    button_margin = 50
    text_margin = 10
    bottom_height = HEIGHT - playbar_height

    # Playbar elements uses settings math to
    # allow for easier positioning and style
    # tinkering
    add_element(ELEMENT,0,bottom_height,WIDTH,playbar_height,PRIMARY,PLAYBAR, "rect_playbar_background")     # Play Panel
    add_element(ELEMENT,0,bottom_height - 5,WIDTH,5,TIERTARY,PLAYBAR,"rect_empty_bar")    # Duration Empty Bar
    add_element(ELEMENT,0,bottom_height - 5,progress,5,PROGRESS_BAR,PLAYBAR,"rect_duration_bar")     # Duration Bar
    add_element(IMAGE,0, HEIGHT - playbar_height, playbar_height,playbar_height, IMAGE_COLOR, PLAYBAR, "img_play_thumbnail", @playing_thumbnail)
    add_element(FONT,playbar_height + text_margin,bottom_height + text_margin,PLAYBAR,1.0,HIGHLIGHT,"txt_album",@playing_album_name)
    add_element(FONT,playbar_height + text_margin,bottom_height + text_margin + @info_font.height,PLAYBAR,0.7,TEXT, "txt_album_song",@playing_song_name)

    # Uses an arrand and a each loop to evenly
    # and dynamicly space out all of the playbar
    # buttons
    playbar_images = ["repeat","fast_forward",@pause_play,"fast_backward", "stop"] #Contains image names
    image_spacing = 50
    playbar_images.each_with_index do |image, index|
        add_spacing = (index * image_spacing)
        total_spacing = image_spacing * playbar_images.length / 2
        size = 25 # Controls size of images
        # Image element adds file path tags combind with the array
        add_element(IMAGE,(WIDTH / 2 + total_spacing) - (add_spacing) - (size / 2),HEIGHT - (playbar_height / 2) - (size / 2),size,size,IMAGE_COLOR,BUTTONS,"play_button_#{index}","images/" + image + ".png")
    end
end

window = Window.new # Creates a new instance of game window
# no preloading
window.show # Makes 'window' visable

