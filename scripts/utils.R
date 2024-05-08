#utility functions for creating the report 
#creating a tidy function for plotting survClust statistics after cross validation 
plotStats_tidy <- function(x, highlight_k=NULL){
    
    colnames(x) = paste0("k", 2:(ncol(x)+1))
    x_df <- x %>%
        as.data.frame() %>%
        dplyr::mutate(cv_rounds = 1:nrow(x)) %>%
        tidyr::pivot_longer(cols = -cv_rounds, names_to = "k") 
    
    pp <- x_df %>%
        ggplot(aes(x = k, y = value)) + 
        geom_boxplot(col = "lightblue") + 
        ggbeeswarm::geom_beeswarm() + 
        theme_minimal()
    
    if(!is.null(highlight_k)){
        
        x_df <- x_df %>%
            mutate(k_col = case_when(k %in% paste0("k",highlight_k) ~ 1, 
                                     TRUE ~ 0)) %>%
            mutate(k_col = as.factor(k_col))
        
        pp <- x_df %>%
            ggplot(aes(x = k, y = value)) + 
            geom_boxplot(aes(col = k_col)) + scale_color_manual(values = c("lightblue", "darkred"))+
            ggbeeswarm::geom_beeswarm() + 
            theme_minimal() + theme(legend.position = "none")
    }
    return(pp)
}

#converting output from ploStats such as lr, spwss into long form
make_long <- function(x){
    
    colnames(x) = paste0("k", 2:(ncol(x)+1))
    x <- x %>% 
        as.data.frame() %>%
        mutate("cv" = paste0("cv", 1:nrow(x))) %>%
        pivot_longer(cols = -cv, names_to = "k_class")
    
    return(x)
}

#this function takes the output of plotStats across individual data types and integrated and returns combined logrank, spwss and frequency of bad soutions. For logrank and spwss, median value across cross validation rounds is returned.  

make_integrated_data <- function(dat1, dat2, integ){
    
    var_type <- names(dat1)
    all_dat <- pmap(list(dat1, dat2, integ, var_type), 
                    function(x,y,z, v){
                        if(v != "bad.sol"){
                            
                            x_long <- make_long(x)
                            x_long <- x_long %>%
                                rename("dat1" = value)
                            
                            y_long <- make_long(y)
                            y_long <- y_long %>%
                                rename("dat2" = value)
                            
                            z_long <- make_long(z)
                            z_long <- z_long %>%
                                rename("integ" = value)
                            
                            df <- inner_join(z_long, 
                                             inner_join(x_long, y_long, by = c("cv","k_class")), 
                                             by = c("cv", "k_class")) %>% 
                                pivot_longer(cols = -c(cv, k_class), names_to = "type") %>%
                                group_by(k_class, type) %>%
                                summarise(med = median(value), 
                                          q_25 = quantile(value, probs = 0.25), 
                                          q_75 = quantile(value, probs = 0.75), .groups = 'drop') 
                            
                            return(df)
                        }
                        if(v == "bad.sol"){
                            data.frame(k_class = paste0("k", 2:(length(x)+1)), 
                                       dat1 = x, dat2 = y, integ = z)}
                    })
}

#this function take the output from make_integrated_data and returns combined logrank, spwss and number of bad solution plots. 
make_integrated_plots <- function(x){
    
    p1 <- x[[1]] %>% 
        ggplot(aes(x=k_class, y=med, group=type, color=type)) +
        geom_line() +
        geom_point()+
        geom_errorbar(aes(ymin=q_25, ymax=q_75), width=.2,
                      position=position_dodge(0.1), alpha = 0.6) + theme_minimal() + 
        ylab("median logrank test statistic over 10 cv rounds")
    
    p2 <- x[[2]] %>% 
        ggplot(aes(x=k_class, y=med, group=type, color=type)) +
        geom_line() +
        geom_point()+
        geom_errorbar(aes(ymin=q_25, ymax=q_75), width=.2,
                      position=position_dodge(0.1), alpha = 0.6) + theme_minimal() + 
        ylab("median SPWSS over 10 cv rounds")
    
    p3 <- x[[3]] %>%
        pivot_longer(cols = -k_class, names_to = "type") %>%
        ggplot(aes(x = k_class, y = value, group = type, color = type)) + 
        geom_line() + 
        geom_point() + 
        ylab("no. of cv solutions with <= 5 cluster size") + 
        theme_minimal()
    
    return(list(p1=p1, p2=p2, p3=p3))
    
}