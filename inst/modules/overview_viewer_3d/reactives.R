session = getDefaultReactiveDomain()
input = getDefaultReactiveInput()
output = getDefaultReactiveOutput()
local_data = reactiveValues(
    mask_name = NULL,
    to_be_imported = NULL
)
env = new.env()
env$masks = new.env(parent = baseenv())
.module_path = 'Viewer3D'
.module_id = 'viewer_3d'
bgcolor = '#ffffff'
mouse_control = 'trackball'




data_controls_name = function(){
    local_data$refresh_controller
    name = local_data$mask_name
    if(!length(name) == 1 || !name %in% names(as.list(env$masks))){
        name = NULL
    }
    local_data$refresh_control_pane = Sys.time()
    selectInput(ns('mask_name'), 'Select a Dataset for Visualization', choices = c('_Blank', names(as.list(env$masks))), selected = name)
}

data_controls_misc = function(){
    tagList(
        checkboxInput(ns('col_sym'), 'Symmetric Color', value = T),
        downloadLink(ns('export'), 'Download 3D Viewer')
    )
}

output$export <- downloadHandler(
    filename = function(){
        'rave_3d_viewer.html'
    },
    content = function(con){
        showNotification(p('Generating... This will take a while'), type = 'message', duration = NULL, id = ns(.module_id))
        htmlwidgets::saveWidget(viewer(), con)
        showNotification(p('Done!'), type = 'message', id = ns(.module_id), duration = 5)
    }
)

data_controls_details = function(){
    local_data$refresh_control_pane
    name = local_data$mask_name
    name %?<-% '_Blank'
    ui = NULL
    if(name %in% .preserved){
        # mask = env$masks[[name]]
        # local_data$controller_data = mask
        return(get_ui(name))
    }
    if(name %in% names(as.list(env$masks))){
        mask = env$masks[[name]]
        local_data$controller_data = mask
        if(!is.null(mask)){
            switch(
                mask$type,
                'static' = {
                    ui = tagList(
                        selectInput(ns('main_var'), 'Display Colours', choices = mask$header),
                        selectInput(ns('thred_var'), 'Threshold', choices = mask$header),
                        sliderInput(ns('thred_rg'), 'Range', min = 0, max = 1, value = c(0,1), round = -2L),
                        selectInput(ns('info_var'), 'Click Info', choices = mask$header, multiple = T, selected = mask$header)
                    )
                },
                'animation' = {
                    ui = tagList()
                }
            )
        }
    }
    ui
}

observe({
    local_data$mask_name = input$mask_name
    local_data$col_sym = input$col_sym
    local_data$main_var = input$main_var
    local_data$thred_var = input$thred_var
    local_data$thred_rg = input$thred_rg
    local_data$info_var = input$info_var
})

observe({
    try({
        mask = local_data$controller_data
        if(is.null(mask) || is.null(mask$body)){
            return()
        }
        thred_var = local_data$thred_var
        col = mask$header == thred_var
        val = mask$body[, col]
        val = as.numeric(val)
        val = val[!is.na(val)]
        if(length(val)){
            val = range(val, na.rm = T)

            if(val[1] < val[2]){
                val[1] = floor(val[1] * 100) / 100
                val[2] = ceiling(val[2] * 100) / 100
                updateSliderInput(session, 'thred_rg', label = sprintf('Range (%s)', thred_var), min = val[1], max = val[2], value = val, step = 0.001)
            }
        }
    }, silent = T)
})



viewer = function(){
    try({
        local_data$controller_data
        name = isolate(local_data$mask_name)
        name %?<-% '_Blank'
        if(name %in% names(as.list(env$masks))){
            mask = local_data$controller_data
        }else{
            mask = NULL
        }
        mask %?<-% list(
            electrodes = NULL,
            values = NULL
        )
        mask$type %?<-% '_blank'

        col_sym = local_data$col_sym
        col_sym %?<-% T

        marker = apply(subject$electrodes, 1, function(x){
            as.character(p(
                tags$small(sprintf(
                    '%s, %s', x['Group'], x['Type']
                ))
            ))
        })

        switch (mask$type,
                '_blank' = {
                    return(
                        module_tools$plot_3d_electrodes(
                            tbl = subject$electrodes,
                            # marker = marker,
                            # fps = 1,
                            # loop = F,
                            control_gui = T
                            # background_colors = c(bgcolor, '#000000'),
                            # control = mouse_control
                        )
                    )

                },
                'static' = {
                    main_var = local_data$main_var
                    thred_var = local_data$thred_var
                    # thred_rg = local_data$thred_rg
                    thred_rg %?<-% c(-Inf, Inf)
                    info_var = local_data$info_var
                    body = mask$body[order(mask$electrodes), ]
                    mask$electrodes = sort(mask$electrodes)

                    # thred value
                    values = as.numeric(body[, mask$header == main_var])
                    t_vals = as.numeric(body[, mask$header == thred_var])
                    sel = !is.na(t_vals) & t_vals %within% thred_rg & (mask$electrodes %in% subject$filter_all_electrodes(mask$electrodes))

                    body = mask$body[sel, ]
                    values = values[sel]
                    electrodes = mask$electrodes[sel]

                    if(length(info_var)){
                        # marker should be shown even the electrode is filtered out
                        sapply(info_var, function(v){
                            mk = unlist(mask$body[, mask$header == v])
                            if(is.numeric(mk)){
                                # mk = sprintf('%.4f', mk)
                                mk = prettyNum(mk, digits=4, format="fg")
                            }
                            sapply(mk, function(x){
                                as.character(
                                    tags$li(tags$label(v), ' ', x)
                                )
                            })
                        }) ->
                            tmp
                        apply(tmp, 1, function(x){
                            as.character(
                                div(
                                    tags$ul(HTML(x))
                                )
                            ) ->
                                s
                            str_remove_all(s, '\\n')
                        }) ->
                            tmp
                        in_mask = subject$electrodes$Electrode %in% mask$electrodes
                        marker[in_mask] = str_c(
                            marker[in_mask],
                            tmp
                        )
                    }else{
                        marker = NULL
                    }

                    return(
                        module_tools$plot_3d_electrodes(
                            electrodes = electrodes,
                            values = values,key_frame = 0,
                            marker = marker,
                            control_gui = T
                        )
                    )

                },
                'animation' = {
                    return(
                        module_tools$plot_3d_electrodes(
                            electrodes = mask$electrodes,
                            key_frame = mask$header,
                            values = t(mask$body),
                            control_gui = T
                        )
                    )

                }
        )
    }, silent = T)



}




