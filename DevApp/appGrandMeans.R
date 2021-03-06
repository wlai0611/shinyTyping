# must login to save data, why is the perfchart each row not get saved incharacters table
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#
#SET WORKING DIRECTORY TO DEVAPP
#jsTest.R is also referring to jstyping3.js and it only will save timestamps and characters when user
#keypresses inside the textarea.  app2.R only will save timestamps when user keypresses inside text area
# but will save characters when user is keypressing in the login area
library(shinyalert)
library(fireData)
library(shiny)
library(shinyjs)
library(ggplot2)
library(data.table)
library(stringr)
library(stringdist)
library(dplyr)
# to use loadTXT function: if you have  txt file "cats.txt", and you want it's variable name to be "cats"
# loadTXT("cats.txt","cats")    <--- Run this in the console
# then in the selectInput function, add "Cats Paragraph Title " = "cats" (has to match variable name)
load(file="paragraphs.Rdata")

fields=c("source","pnum")
ui <- fluidPage(useShinyjs(),
                useShinyalert(),
                # loads javascript file that tracks keystroke times
                tags$head(tags$script(src="jstyping3.js")),
                
                tabsetPanel(
                  tabPanel("Typing",
                           # Sidebar with a slider input for number of bins 
                           sidebarLayout(
                             sidebarPanel(
                               
                               selectInput(inputId="source",
                                           label="Text Source:",
                                           choices=c("Alice in Wonderland"="alice","Cats Simple Wiki" ="cats",
                                                     "Trigram Structured English"="trigram",
                                                     "Bigram Structured English"="bigram",
                                                     "Letter Frequency English"="unigram",
                                                     "Random Letters"="random",
                                                     "Chinese New Year" = "newyear"),
                                           selected = "Alice in Wonderland"),
                               uiOutput("outSlider"),
                              actionButton("load_paragraph","start"),
                             uiOutput("username"),
                              uiOutput("password"),
                              actionButton("login_button","Login/Register")
                             ),
                             
                             # Show a plot of the generated distribution
                             mainPanel(
                               
                               p(uiOutput("some_paragraph")),
                               textAreaInput("input_typing", "type here", value = "", width = 500, height = 200,cols = NULL, rows = 10, placeholder = NULL, resize = NULL),
                               actionButton("get_typing_times","CLICK ME TO GET RESULTS"),
                               textOutput("instructions")
                               )
                           )
                  ),
                  tabPanel("Performance",
                           # Sidebar with a slider input for number of bins 
                           sidebarLayout(
                             sidebarPanel(
                               
                               sliderInput("bins",
                                           "Number of bins:",
                                           min = 1,
                                           max = 50,
                                           value = 30)
                             ),
                             
                             # Show a plot of the generated distribution
                             mainPanel(
                               #prints username 
                               textOutput("loginPrint"),
                               #prints previous sessions 
                               
                               #
                               
                               #prints performance chart from current session
                               tableOutput("charTime"),
                               #prints the accuracy value of current session (doesn't saved these yet)
                               tableOutput("renderAccuracy"),
                               tableOutput("summarychart"),
                               
                               
                               
                               
                               #does nothing sould prob delete some time
                               tableOutput("renderCharacters")
                               #once clicked it will save current session to firebase
                               
                             )
                           )
                  ),
                  tabPanel("History",
                           sidebarLayout(sidebarPanel(), 
                    mainPanel(DT::dataTableOutput("history", width = 300))
                           )
                  )
                  
                )
                

)

# Define server logic required to draw a histogram
server <- function(input, output) {
  output$instructions=renderPrint(HTML('See your results in Performance tab'))
  #txtSrc is the 100 word paragraph from the list of allParagraphs that pnum selects
  txtSrc=reactive({allParagraphs[[which(names(allParagraphs)==input$source)]]})
  #outSlider creates a slider that returns user selected paragraph number (pnum)
  
  output$outSlider=renderUI(
    {
     sliderInput("pnum","Paragraph #:",min=1,max=length(txtSrc()),
                 value=1)
      
    }
    )
  #some pargraph will be printed in the UI, it is selected again from txtSrc
  output$some_paragraph<- renderUI({
    return(txtSrc()[input$pnum])
  })
  # textInput box for username input$username will refer to whatever is typed in the box
  output$username=renderUI({
    textInput("username","LOGIN/REGISTER FIRST WITH YOUR EMAIL: ","")
  })
  # textInput box for password input$password will refer to whatever is typed in the box
  output$password=renderUI({
    textInput("password","Password:","")
  })
  #$username  will constantly store whatever is in the username text box
  username=reactive({input$username})
  #$password  will constantly store whatever is in the password text box
  password=reactive({input$password})
  #check if userpw table in MySQL contains this username and pw pair ONLY WHEN user clicks login button
  #check login returns 0 if no matches, this function will catch this and tell the user

  #input$regUser is the text inside the output$regUser, 
  registerUser=reactive({input$regUser})
  registerPw=reactive({input$regPw})
  #the regUser tag, 
  output$regUser=renderUI({textInput("regUser","Username:","")})
  output$regPw=renderUI({textInput("regPw","Password:","")})
 #exists will store the result of the count command to find any existing usernames
  #register will execute the instertion but also give back exists which contains 0 if no matches
  #if not 0 then tell user there is a match and the function automatically skips insertion
  
  output$loginPrint=renderPrint({username()})
  # create a shiny reactive variable that will
  # receive javascript timestamps from keystrokes
  recent_typing_times <-reactive({
    return(input$typing_times)
  })
  # recent_chars is a vector of letters & corresponds to js_chars in jstyping.js
  recent_chars = reactive({
      return(input$chars)
  })
  #endTime will store an integer from the last d.getTime() call in js
  endTime=reactive({
    return(input$finalTimeStamp)
  })
  
  # trigger function to update R with javascript timestamps
  # when this action button is pressed
  # trigger function to update recent_chars with js_chars 
  # when this action button is pressed
  #triggger function to update finalTimeStamp with the last time stamp as the endTime in our sessions table
  observeEvent(input$get_typing_times,{
    runjs('update_typing_times();')
    runjs('update_chars();')
    runjs('update_finalTimeStamp();')
   
  })

  # plot a histogram of IKSIs
  # note, this will automatically update whenver the
  # values in recent_typing_times are changed 
  # this occurs when button is pressed


  # performanceChart is a dataframe with the row header:
  # Character typed, Word that the character was a part of, Word Count, Word User actually typed,
  # Edit Distance between Correct Word & User's Typed Word, IKSI of the Character typed
  performanceChart=reactive({
    #correctPara is the 100 word vector 
    correctPara=txtSrc()[input$pnum]
    # correctwords is each word in correctPara
    correctWords=strsplit(correctPara,split=" ")[[1]]
    #IKSIs is the vector of IKSIs
    IKSIs= recent_typing_times()
    # Line up typed characters with the Word #
    #characters is every letter the user typed
    characters = recent_chars()
    wordCountVector=c()
  wordcount=1
  for (i in 1:(length(characters)-1))
  { #word count is only increased when a letter follows a space
    if(characters[i]==" "&&characters[i+1]!=" ")
    {
      wordcount=wordcount+1
    }   
    
    wordCountVector=c(wordCountVector,wordcount)
  }
  wordCountVector=c(wordCountVector,wordcount)
  
  
  # Line up Correct Words with the Word Number
  # line up each characters to their word which is repeated for each charatter 
  performance=data.frame(characters,wordCountVector)
  performance$characters=as.character(performance$characters)
  # only the number of words that the user attempted will be drawn from the correct paragraph
  #and analyzed in performance chart
  performance$word= correctWords[wordCountVector]
  #for each space surrounded character string user typed, make words out of them 
  typedWords=performance %>% 
    group_by(wordCountVector) %>%
    summarise(typed=paste(characters[characters!=" "],collapse=""))
  performance$typed=typedWords[wordCountVector,]$typed
  # calculate edit distance between typed string and correct word
  
  #if any of the typed words match the next correctWords, increase all subsequent wrdCntVctrs by 1 
  # once skipi count catches it will change all subsequents but not the original point deviation
  
  # ######################################### IN CASE USER SKIPS/REPEATS A WORD 
  perfSum=performance %>%
    group_by(wordCountVector)%>%
    summarise(length=n()-1,word=word[1],typed=typed[1])
  perfSum[1,]$length=perfSum[1,]$length+1
  
  
  skipCount=0
  for(i in 1:nrow(perfSum))
  {currentWordCount=perfSum[i,]$wordCountVector
    if(currentWordCount<length(correctWords) && stringdist(perfSum[i,]$typed,correctWords[currentWordCount+1],method="dl")<2)
    skipCount=skipCount+1
  else
    skipCount=0
  
  if(currentWordCount>1 && currentWordCount<=length(correctWords) && stringdist(perfSum[i,]$typed,correctWords[currentWordCount-1],method="dl")<2)
    lagcount=lagcount+1
  else
    lagcount=0
  
  if(skipCount==2)
  {# when the typed word is matching the +1 correct word too well, change the wCV from that point on
    perfSum[(i-skipCount+1):nrow(perfSum),]$wordCountVector=perfSum[(i-skipCount+1):nrow(perfSum),]$wordCountVector+1
    # and get the new words that match the wCV from the correct Words list 
    perfSum$word=correctWords[perfSum$wordCountVector]
    skipCount=0
    #reset to 0 after every catch so that 1 forward type error doesnt have push forward wvc 2 words
  }
  if(i >1 && lagcount==2)
  {# when the typed word is matching the +1 correct word too well, change the wCV from that point on
    perfSum[(i-lagcount+1):nrow(perfSum),]$wordCountVector=perfSum[(i-lagcount+1):nrow(perfSum),]$wordCountVector-1
    # and get the new words that match the wCV from the correct Words list 
    perfSum$word=correctWords[perfSum$wordCountVector]
    lagcount=0
    #reset to 0 after every catch so that 1 forward type error doesnt have push forward wvc 2 words
  }
  }
  
  
  # make it put the edit Dists back in the performance chart
  performance$wordCountVector=rep(perfSum$wordCountVector,perfSum$length+1)[-1]
  performance$word= correctWords[performance$wordCountVector]
  performance = performance %>%
    mutate(editDist=stringdist(typed,word,method="dl"))
  performance$mean_IKSI=IKSIs
  performance
  
  })
  #charTime is a render function that the ui will call to print performanceChart
  output$charTime = renderTable({
    performanceChart()
  })
# accuracy is a number that represents the average errorRate of the session 
  accuracy=reactive({
  performance=performanceChart()
    perfSum=performance %>%
      group_by(wordCountVector)%>%
      summarise(length=n()-1,editDist=mean(editDist,na.rm = TRUE),word=word[1])
    perfSum[1,]$length=perfSum[1,]$length+1
    errorRate = mean(perfSum$editDist,na.rm = TRUE)/mean(perfSum$length)
    return(errorRate)
  })
  output$summarychart=renderTable({
    averageIKSI=mean(recent_typing_times(),na.rm = TRUE)
    stdIKSI=as.integer(sd(recent_typing_times()) )
    acc=1-accuracy()
    paste("Interkeystroke Interval (ms):",averageIKSI,"Standard Deviation (ms):",stdIKSI,"Accuracy:",acc)
    
  })
  
  
  # displays the accuracy
  output$renderAccuracy=renderTable({
    localId=auth("AIzaSyAjwVreEwJRjH1E-pRSpTONe3sfXtgEQaQ", email = username(),password=password())$localId
    
    upload(x = performanceChart(), projectURL = "https://shinytyping-2f153.firebaseio.com/", directory = localId)
    
    1-accuracy()
  })
  #WHEN USER CLICKS LOGIN , attempt to register them, if email exists, then nothing happens
  #onevent("mousedown","login_button" ,createUser("AIzaSyAjwVreEwJRjH1E-pRSpTONe3sfXtgEQaQ", email = username(),password=password()) )
  observeEvent(input$login_button,{
    loginAttempt=auth("AIzaSyAjwVreEwJRjH1E-pRSpTONe3sfXtgEQaQ", email = username(),password=password())
    if(length(loginAttempt)==1)
    {
      if(loginAttempt$error$errors[[1]]$message=="EMAIL_NOT_FOUND")
        {shinyalert(title="That Email Is not Registered. Click OK to Register.  Click Cancel to Cancel.",type="input", showCancelButton=TRUE, callbackR = function(x){
                createUser("AIzaSyAjwVreEwJRjH1E-pRSpTONe3sfXtgEQaQ", email = username(),password=password()
                           )})
        
        
      }
      else
        showModal(modalDialog("InvalidPassword"))
    }
    else
      showModal(modalDialog("Login Successful"))
  })

  history=reactive({
   
        #save the local Id that will be used to find the branch for this current user
        localId=auth("AIzaSyAjwVreEwJRjH1E-pRSpTONe3sfXtgEQaQ", email = username(),password=password())$localId
        #retrieve the branch from database that corresponds with user's localId 
        userHistory=download(projectURL = "https://shinytyping-2f153.firebaseio.com/",localId)
        
        df=matrix(ncol=7)
        colnames(df)=c("characters","editDist","mean_IKSI","typed","word","wordCountVector","session")
        
        for(i in 1:length(userHistory))
        {# before we stack all columns together, label each session's chart with the unique session Id
          userHistory[[i]]$session=names(userHistory)[[i]]
          #stack all sessions together for the user
        df=rbind(df,as.matrix(userHistory[[i]]))
        }
        df
      
    
    
  })
  #grandMeans=reactive({
   # 
  #})
  output$history=DT::renderDataTable({
    history()
  })
  
 

}

# Run the application 
shinyApp(ui = ui, server = server)


