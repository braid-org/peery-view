# Login Form
dom.LOGIN = (c) ->
    button_style =
        justifySelf: "center"
        minWidth: "80%"
        paddingLeft: "5px"
        paddingRight: "5px"
    

    DIV
        width: "min(400px, 75%)"
        display: "grid"
        # Maybe use flex instead here?
        marginLeft: "auto"
        marginRight: "auto"
        grid: '"error error" auto
               "name name" 32px
               "pw pw" 32px
               "email email" 32px
               "register login" 24px
                / auto auto'
        gap: "6px"
        DIV
            gridArea: "error"
            display: "none" unless c.error
            borderBottom: "2px solid red"
            c.error
        INPUT
            id: "login-name"
            placeholder: "Username"
            gridArea: "name"
        INPUT
            id: "login-pw"
            placeholder: "Password"
            gridArea: "pw"
        INPUT
            id: "login-email"
            placeholder: "Email, if registering"
            gridArea: "email"

        BUTTON {
            gridArea: "register"
            button_style...

            onClick: (e) ->
                name = document.getElementById("login-name").value
                pw = document.getElementById("login-pw").value
                em = document.getElementById("login-email").value
                c.create_account =
                    name: name
                    pass: pw
                    email: em
                save c
            },
            "Register"
        BUTTON {
            gridArea: "login"
            button_style...
            onClick: (e) ->
                name = document.getElementById("login-name").value
                pw = document.getElementById("login-pw").value
                c.login_as =
                    name: name
                    pass: pw
                save c
            },
            "Login"

dom.SETTINGS = ->
    c = fetch "/current_user"
    unless c.logged_in
        return
    DIV
        width: "min(400px, 75%)"
        display: "grid"
        # Maybe use flex instead here?
        marginLeft: "auto"
        marginRight: "auto"
        alignContent: "center"
        padding: "0 15px 15px 15px"
        grid: '"nametag namefield namefield" 32px
               "emailtag emailfield emailfield" 32px
               "pictag picfield picfield" 32px
               ". cancel save" 24px
                / auto auto auto'
        gap: "5px"
        
        DIV
            gridArea: "nametag"
            "Name"
        INPUT
            gridArea: "namefield"
            value: c.user.name
            id: "name-change"

        DIV
            gridArea: "emailtag"
            "Email"
        INPUT
            gridArea: "emailfield"
            value: c.user.email
            id: "email-change"

        DIV
            gridArea: "pictag"
            "Avatar URL"
        INPUT
            gridArea: "picfield"
            value: c.user.pic
            placeholder: "http://..."
            id: "pic-change"

        BUTTON
            gridArea: "cancel"
            onClick: (e) ->
                s = fetch "show_settings"
                s.show = false
                save s
            "Cancel"
        BUTTON
            gridArea: "save"
            onClick: (e) ->
                
                # Another option would be to live-update these.
                name = document.getElementById("name-change").value
                email = document.getElementById("email-change").value
                pic = document.getElementById("pic-change").value ? ""

                c.user.name = name
                c.user.email = email
                c.user.pic = pic

                save c.user
                
                # Close the settings box
                s = fetch "show_settings"
                s.show = false
                save s
            "Save"
