'use strict'

angular
  .module 'rentswatchApp'
    .controller 'MainCtrl', ($scope, $timeout, stats, settings, hotkeys)->
      'ngInject'
      # Return an instance of the class
      new class
        # Current step
        step: 0
        stepCount: 12
        # rent: 3000
        # space: 35
        # An image with all ads
        allAds: new Image
        # Default currency
        currency: settings.DEFAULT_CURRENCY
        # List of available currencies
        currencies: settings.CURRENCIES
        constructor: ->
          # Set the Image src to start loading it
          @allAds.src =  '/api/docs/all.png'
          # Start randomized estimation loop
          do @estimationLoop
          # Bind keyboard shortcuts
          hotkeys.add
            combo: ['right', 'space']
            description: "Go to the next screen."
            callback: @next
          hotkeys.add
            combo: ['left']
            description: "Go to the previous screen."
            callback: @previous
          # Save the currency's conversion rate
          $scope.$watch 'main.currency', (c)=>
            if c? and @currencies[c]?
              @rate = @currencies[c].CONVERSION_RATE
        # Create axis ticks
        xticks: =>
          min  = 20
          max  = settings.MAX_LIVING_SPACE
          tick = 20
          ( Math.round(t * min) for t in [0..(max/tick)-1] )
        yticks: =>
          min  = @rate * 200
          max  = @rate * settings.MAX_TOTAL_RENT
          tick = @currencies[@currency].TICK
          ( Math.round(t * min) for t in [0..(max/tick)-1] )
        # Comparaison helper
        in: (from, to=1e9)=> @step >= from and @step <= to
        is: (s)=> @step is s
        # Go the next step
        next: =>
          # Disabled going further step 0 without rent
          return if @step + 1 > 0 and not @rent
          # Disabled step beyond the end
          return if @step + 1 > 6 and not @space
          # Disabled step beyond the end
          return if @step >= @stepCount - 1
          # We can go further
          @step++
        previous: =>
          @step-- if @step > 0
        # Get the part of the user rent's according to the max value
        userRentPart: =>
          @rent/(@rate * settings.MAX_TOTAL_RENT) * 100 + '%'
        # Get position of the user point
        userPoint: =>
          bottom: do @userRentPart,
          left: @space/settings.MAX_LIVING_SPACE * 100 + '%'
        # Get the user level compared to other decades
        userRentLevel: =>
          rent = @rate * @rent
          # Count smaller and higher values
          figures = _.reduce stats.decades, (res, row)=>
            res.smaller += row.count * (row.to <= rent)
            res.higher += row.count * (row.from > rent)
            res
          , higher: 0, smaller: 0
          # Compute level
          figures.level = figures.smaller/( figures.smaller + figures.higher)
          # Returns the 3 figures
          figures
        # There is approximatively 1 ad scraped by second so
        # we should be able to estimated approximatively the number
        # of ad currently in the database.
        estimateAds: ->
          stats.total + ~~(stats.pace * (Date.now()/1e3 - stats.lastSnapshot))
        # This will trigger an infinite (and irregular loop of estimation)
        estimationLoop: =>
          # This value will be updated regulary
          @totalAds = do @estimateAds
          # Use a random timeout to estimate the number of ad
          $timeout @estimationLoop, Math.random() * 1000
        yArrowStyle: (growth=@currencies[@currency].DEMO_GROWTH, rent=@currencies[@currency].DEMO_RENT)=>
          rent = rent / @rate
          growth = growth / @rate
          left: rent * stats.slope / settings.MAX_LIVING_SPACE * 100 + '%'
          bottom: rent / settings.MAX_TOTAL_RENT * 100 + '%'
          height: growth / settings.MAX_TOTAL_RENT * 100 + '%'
        xArrowStyle: (growth=@currencies[@currency].DEMO_GROWTH, rent=@currencies[@currency].DEMO_RENT)=>
          rent = rent / @rate
          growth = growth / @rate
          left: rent * stats.slope / settings.MAX_LIVING_SPACE * 100 + '%'
          bottom: (rent / settings.MAX_TOTAL_RENT * 100) + (growth / settings.MAX_TOTAL_RENT * 100) + '%'
          width: growth * stats.slope / settings.MAX_LIVING_SPACE * 100 + '%'
        # Draw the linear regression of the data
        losRegression: (slope=stats.slope)=>
          cvswidth = cvsheight = 480*2
          canvas = angular.element("<canvas />").attr width: cvswidth, height: cvsheight
          ctx = canvas[0].getContext '2d'

          MAX_TOTAL_RENT = settings.MAX_TOTAL_RENT
          # Create scale for y (rent)
          y = d3.scale.linear().domain([0, MAX_TOTAL_RENT]).range [cvsheight, 0]
          # Points color
          ctx.strokeStyle = "#ffd633"

          do ctx.beginPath
          ctx.moveTo 0, cvsheight
          ctx.lineWidth = 2
          ctx.lineTo cvswidth, y(settings.MAX_LIVING_SPACE / slope)
          do ctx.stroke

          # Returns a base64
          do canvas[0].toDataURL
