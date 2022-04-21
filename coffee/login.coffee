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
            ref: "login-name"
            placeholder: "Username"
            gridArea: "name"
        INPUT
            id: "login-pw"
            ref: "login-pw"
            placeholder: "Password"
            gridArea: "pw"
            type: "password"
        INPUT
            id: "login-email"
            ref: "login-email"
            placeholder: "Email"
            gridArea: "email"
            type: "email"

        BUTTON {
            gridArea: "register"
            button_style...

            onClick: (e) =>
                name = @refs["login-name"].getDOMNode().value
                pw = @refs["login-pw"].getDOMNode().value
                em = @refs["login-email"].getDOMNode().value
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
            onClick: (e) =>
                name = @refs["login-name"].getDOMNode().value
                pw = @refs["login-pw"].getDOMNode().value
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
            ref: "name"
            value: c.user.name
            id: "name-change"

        DIV
            gridArea: "emailtag"
            color: "#333"
            fontSize: "12px"
            "Email"
        INPUT
            gridArea: "emailfield"
            ref: "email"
            value: c.user.email
            id: "email-change"
            type: "email"

        DIV
            gridArea: "pictag"
            color: "#333"
            fontSize: "12px"
            "Avatar URL"
        INPUT
            gridArea: "picfield"
            ref: "pic"
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
            ref: "filter"
            value: c.user.filter
            placeholder: -0.2
            id: "filter-change"
            type: "number"
            step: 0.1


        BUTTON
            gridArea: "cancel"
            onClick: (e) =>
                s = fetch "show_settings"
                # Should reset values of INPUTs here
                s.show = false
                save s
            "Cancel"
        BUTTON
            gridArea: "save"
            onClick: (e) =>
                
                name = @refs.name.getDOMNode().value
                email = @refs.email.getDOMNode().value
                pic = @refs.pic.getDOMNode().value ? ""
                filter = @refs.filter.getDOMNode().value ? -0.2

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
