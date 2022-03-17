# Login Form
dom.LOGIN = ->
    c = fetch "/current_user"
    button_style =
        justifySelf: "center"
        minWidth: "80%"
        paddingLeft: "5px"
        paddingRight: "5px"

    DIV
        width: 200
        paddingRight: "10px"
        display: "grid"
        # Maybe use flex instead here?
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
            fontSize: "12px"
            color: "red"
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
            placeholder: "Email"
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

                s = fetch "show_settings"
                s.show = false
                save s
            },
            "Login"

dom.SETTINGS = ->
    c = fetch "/current_user"
    unless c.logged_in
        return
    DIV
        width: "250"
        display: "grid"
        # Maybe use flex instead here?
        alignContent: "center"
        grid: '"nametag namefield namefield" 32px
               "emailtag emailfield emailfield" 32px
               "pictag picfield picfield" 32px
               "filtertag filterfield filterfield" 32px
               ". cancel save" 24px
                / auto auto auto'
        gap: "5px"
        
        DIV
            gridArea: "nametag"
            color: "#333"
            fontSize: "12px"
            "Name"
        INPUT
            gridArea: "namefield"
            value: c.user.name
            id: "name-change"

        DIV
            gridArea: "emailtag"
            color: "#333"
            fontSize: "12px"
            "Email"
        INPUT
            gridArea: "emailfield"
            value: c.user.email
            id: "email-change"

        DIV
            gridArea: "pictag"
            color: "#333"
            fontSize: "12px"
            "Avatar URL"
        INPUT
            gridArea: "picfield"
            value: c.user.pic
            placeholder: "http://..."
            id: "pic-change"
        DIV
            gridArea: "filtertag"
            color: "#333"
            fontSize: "12px"
            "Min post score"
        INPUT
            gridArea: "filterfield"
            value: c.user.filter
            placeholder: "-0.2"
            id: "filter-change"


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
                filter = document.getElementById("filter-change").value ? -0.2

                c.user.name = name
                c.user.email = email
                c.user.pic = pic
                c.user.filter = Number.parseFloat(filter)

                save c.user
                
                # Close the settings box
                s = fetch "show_settings"
                s.show = false
                save s
            "Save"
