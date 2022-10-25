*** Settings ***
Documentation       Builds robots based on the orders.csv file.
...                 Downloads the csv file, logs in to the intranet,
...                 submits the orders, captures necessary details and
...                 zips all receipts together.

Library             RPA.Archive
Library             RPA.Browser.Selenium    auto_close=${False}
Library             RPA.Dialogs
Library             RPA.FileSystem
Library             RPA.HTTP
Library             RPA.PDF
Library             RPA.Robocorp.Vault
Library             RPA.Tables


*** Variables ***
${RECEIPTS_PATH}        ${OUTPUT_DIR}${/}receipts
${ROBOT_IMAGE_PATH}     ${OUTPUT_DIR}${/}robot-preview.png
${MAX_RETRY_COUNT}      ${10}


*** Tasks ***
Build robots according to orders
    Ask user's name
    Download the orders
    Open the intranet website
    Log in
    Open the build-a-robot tab
    Fill in and submit all orders
    Zip receipts
    [Teardown]    Log out and close the browser


*** Keywords ***
Ask user's name
    TRY
        Add heading    Hi there!
        Add text    I'm the order handling robot. What's your name?
        Add text input    Name
        ${answer}=    Run dialog
        Add heading    Well hello ${answer.Name}!
        Add text    I'm going to start building some robots.
        Add text    You can just sit and watch.
        Run dialog
    EXCEPT
        Log    Name not given.
    END

Download the orders
    Download    https://robotsparebinindustries.com/orders.csv    overwrite=True

Open the intranet website
    ${intranet_data}=    Get Secret    intranet
    Open Available Browser    ${intranet_data}[url]
    Maximize Browser Window

Log in
    Wait Until Page Contains Element    username
    Input Text    username    maria
    Wait Until Page Contains Element    password
    Input Password    password    thoushallnotpass
    Submit Form
    Wait Until Page Contains Element    id:sales-form

Open the build-a-robot tab
    Wait Until Page Contains Element    link:Order your robot!
    Click Element    link:Order your robot!
    Close popup

Close popup
    Wait Until Page Contains Element    css:div[class="alert-buttons"] > button[class="btn btn-dark"]
    Click Element    css:div[class="alert-buttons"] > button[class="btn btn-dark"]

Fill in and submit all orders
    ${orders}=    Read table from CSV    orders.csv
    FOR    ${row}    IN    @{orders}
        ${order_successful}=    Set Variable    False
        ${retry_number}=    Set Variable    ${1}
        WHILE    ${order_successful} == False
            IF    ${retry_number} <= ${MAX_RETRY_COUNT}
                TRY
                    Fill in and submit one order    ${row}
                    ${order_successful}=    Set Variable    True
                EXCEPT
                    Reload Page
                    Close popup
                    ${order_successful}=    Set Variable    False
                    ${retry_number}=    Set Variable    ${retry_number} + ${1}
                END
            ELSE
                Log    Maximum retries reached.
                BREAK
            END
        END
    END

Fill in and submit one order
    [Arguments]    ${row}
    Select From List By Value    css:div[class="form-group"] > select[id="head"]    ${row}[Head]
    Click Element    css:div[class="radio form-check"] > label[for="id-body-${row}[Body]"]
    Input Text
    ...    css:div[class="form-group"] > input[placeholder="Enter the part number for the legs"]
    ...    ${row}[Legs]
    Input Text    id:address    ${row}[Address]
    Click Button    id:preview
    Wait Until Page Contains Element    id:robot-preview-image
    Screenshot    id:robot-preview-image    ${ROBOT_IMAGE_PATH}
    Submit order
    Save receipt    ${row}[Order number]
    Wait Until Page Contains Element    id:order-another
    Click Button    id:order-another
    Close popup

Submit order
    Wait Until Page Contains Element    id:order
    Click Button    id:order
    Element Should Be Visible    id:order-another

Save receipt
    [Arguments]    ${order_number}
    Wait Until Page Contains Element    id:receipt
    ${receipt}=    Get Element Attribute    id:receipt    outerHTML
    Html To Pdf    ${receipt}    ${RECEIPTS_PATH}${/}${order_number}.pdf
    Open Pdf    ${RECEIPTS_PATH}${/}${order_number}.pdf
    Add Watermark Image To Pdf    ${ROBOT_IMAGE_PATH}    ${RECEIPTS_PATH}${/}${order_number}.pdf
    Close Pdf

Zip receipts
    Archive Folder With Zip    ${RECEIPTS_PATH}    receipts.zip    compression=deflated
    Move File    receipts.zip    ${OUTPUT_DIR}${/}receipts.zip    overwrite=True

Log out and close the browser
    Click Button    Log out
    Close Browser
    Remove File    ${ROBOT_IMAGE_PATH}
    TRY
        Empty Directory    ${RECEIPTS_PATH}
    EXCEPT
        Log    Failed to empty the receipts directory.
    END
