# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

modified = false

$(document).on "page:change", -> 
  routeCoffee()

  if window._gaq?
    _gaq.push ['_trackPageview']
  else if window.pageTracker?
    pageTracker._trackPageview()

$ -> routeCoffee()

routeCoffee = ->

  renderer = null

  getRenderer = ->
    if $('#route_renderer').val() == 'Giro' 
      window.mesmeride.giroRenderer 
    else
      window.mesmeride.h10KBannerRenderer
    
  updateRenderer = ->
    renderer = getRenderer()
    
    $('.renderer-controls').removeClass('visible')
    $("##{renderer.name}-renderer-controls").addClass('visible')
    
    renderer.create()
    
    renderer.zoom = $('#zoom-slider').data('value') / 25
    renderer.scale = $('#scale-slider').data('value') / 25
    renderer.yScale = $('#y-slider').data('value') / 25

    if(window.renderer_options['color']) 
      $('#h10k_color').val(window.renderer_options['color'])
      renderer.color = window.renderer_options['color']
      renderer.postRedraw()
    
    renderer.postRedraw(1000);
  
  $(window).unbind('resize', windowResize)

  if $('body').data('controller') == 'routes' && $('body').data('action') == 'edit'

    # alert('!')
    
    updateRenderer()
    
    
    # if ($('.toolbox').length == 0) then return
    
    #
    # Toolboxes and resizing
    #

    $( ".toolbox,.debug_dump" ).draggable();

    $( "#zoom-slider" ).slider
      value: $('#zoom-slider').data('value')
      min: 1
      max: 100
      change: (event,ui) -> 
        renderer.zoom = ui.value / 25
        renderer.postRedraw()

    $( "#scale-slider" ).slider
      value: $('#scale-slider').data('value')
      min: 1
      max: 100
      change: (event,ui) -> 
        renderer.scale = ui.value / 25
        renderer.postRedraw()

    $( "#y-slider" ).slider
      value: $('#y-slider').data('value')
      min: 1
      max: 100
      change: (event,ui) -> 
        renderer.yScale = ui.value / 25
        renderer.postRedraw()

        # $( "#controls" ).offset({top: $('#tools').offset().top + $('#tools').outerHeight() + 4, left: $('#controls').offset().left});
    $( "#surface-container" ).height($('#bottom-anchor').offset().top - $('.navbar-fixed-top').outerHeight() - $('.footbox').outerHeight());

    #
    # Waypoint manipulation
    #
    
    routeDistance = window.streams.distance[window.streams.distance.length-1]
    
    waypointChange = (e) ->  
      for w in waypoints 
        w.name = $(e).val() if w.id == waypointId(e)
      renderer.postRedraw();
      
    waypointId = (elem) ->
      $(elem).parents('#waypoints table tr').data('id')
      
    getWaypoint = (elem) ->
      id = waypointId(elem)
      for w in waypoints 
        return w if w.id is id
      null
    
    getElevationByDistance = (distance) ->
      for d,i in streams.distance
        return streams.altitude[i] if d >= distance
      return -1
    
    attachWaypointEvents = ->
      $( "#waypoints table tr:not(tr.bound) input[type='text']" ).keyup -> 
        waypointChange this
        modified = true
      
      $( "#waypoints table tr:not(tr.bound) input[type='text']" ).change -> 
        waypointChange this
        modified = true
        
      $( "#waypoints table tr:not(tr.bound) button.close" ).click ->
        for w,i in waypoints
          if w.id == waypointId(this)
            waypoints.splice i,1
            break
        $(this).parent().parent().addClass('disabled')
        $(this).parent().parent().find('.input-destroy').val(1)
        renderer.postRedraw()
        
      $( "#waypoints table tr:not(tr.bound) .waypoint-distance" ).each ->
        refreshWaypoint = (e) ->
          waypoint = getWaypoint(e)
          waypoint.distance = $(e).slider('value')
          waypoint.elevation = getElevationByDistance(waypoint.distance)
          renderer.postRedraw()
          $('.ui-slider-handle',e).tooltip('show')
          
          $(e).parent().parent().find('input[type=hidden]').filter ->
            this.id.match(/route_waypoints_attributes_.*_distance/)
          .val(waypoint.distance)
          
          $(e).parent().parent().find('input[type=hidden]').filter ->
            this.id.match(/route_waypoints_attributes_.*_elevation/)
          .val(waypoint.elevation)

        $(this).slider(
          min: 0
          max: routeDistance
          step: 1
          value: getWaypoint(this).distance
          slide: -> refreshWaypoint(this)
          change: -> refreshWaypoint(this)
            
        #
        # override default keyboard events because pgup/dn are too large an increment
        #
        
        ).keydown (event) ->
          switch event.keyCode
            when $.ui.keyCode.PAGE_UP then $(this).slider('value', Math.max($(this).slider('value') - 100, 0))
            when $.ui.keyCode.PAGE_DOWN then $(this).slider('value', Math.min($(this).slider('value') + 100, routeDistance))
            when $.ui.keyCode.LEFT then $(this).slider('value', Math.max($(this).slider('value') - 1, 0))
            when $.ui.keyCode.RIGHT then $(this).slider('value', Math.min($(this).slider('value') + 1, routeDistance))
            when $.ui.keyCode.HOME then $(this).slider('value', 0)
            when $.ui.keyCode.END then $(this).slider('value', routeDistance)
            else return true
          refreshWaypoint(this)
          event.preventDefault()
          
        #
        # Add a tooltip to the slider
        #

        $('.ui-slider-handle',this).tooltip(
          title: ->
            "#{getWaypoint(this).distance/1000}km"
          trigger: 'hover focus manual'
          animation: false
          container: 'body'
        ).unbind('keydown')
        
      $('#waypoints table tr').addClass('bound')
      
    attachWaypointEvents()
    
    $('form a.add_child').click ->
      association = $(this).attr('data-association')
      template = $('#' + association + '_fields_template').html()
      regexp = new RegExp('new_' + association, 'g')
      new_id = new Date().getTime()

      $('#waypoints table tbody').append(template.replace(regexp, new_id))
      $('#waypoints tr[data-id=""]').data('id', new_id)

      waypoint =
        id: new_id
        distance: 0
        elevation: window.streams.altitude[0]
        name: ''
      window.waypoints.push(waypoint)
      attachWaypointEvents()
      renderer.postRedraw()
      
    #
    # Save and Export
    #

    $('#export-button').click ->
      c = document.getElementById('surface')
      img = c.toDataURL('image/png')
      $('#image_save textarea#data').val(img)
      $('#image_save input#name').val($('#route_name').val())
      $('#image_save').submit()
      
    $('#save-button').click ->
      renderer_options = { color : $('#h10k_color').val() };
      $('#route_renderer_options').val(JSON.stringify(renderer_options))
      $('#route_zoom').val($('#zoom-slider').slider('value'))
      $('#route_x_scale').val($('#scale-slider').slider('value'))
      $('#route_y_scale').val($('#y-slider').slider('value'))
      $('.edit_route').submit()
      
    #
    # Window resizing
    #
    
    windowResize = ->
      $( "#surface-container" ).height($('#bottom-anchor').offset().top - $('.navbar-fixed-top').outerHeight() - $('.footbox').outerHeight())
      renderer.postRedraw()

    $(window).resize -> windowResize()

    #
    # Renderer selection
    #
    
    $('#route_renderer').change ->
      updateRenderer()
      renderer.postRedraw()
      
    $('#h10k_color').change ->
      renderer.color = $(this).val()
      renderer.postRedraw()
      
      