local ui = require("lib.ui.layout.ui")
local frame = require("lib.ui.layout.frame")
local testing = require("lib.ui.layout.testing")

local TestTree = ui.Tree({
    measureContent = function(userdata, painter) return painter or { x = 0, y = 0 } end,
    wrapContent = function(userdata, painter, width)
        local painter = painter or { x = 0, y = 0 }
        local height = painter.x + painter.y - width
        return height < 0 and 0 or height
    end
})

local tests = {
    ["no children, fixed position"] = {
        Gen = function(tree)
            ui.Leaf(tree, frame.Frame { pos = frame.Pos(10, 10), size = frame.Size(100, 50) })
        end,
        Stack = {
            { x = 10, y = 10, w = 100, h = 50 }
        }
    },
    ["one child, fixed position"] = {
        Gen = function(tree)
            ui.Node(tree, frame.Frame { pos = frame.Pos(10, 10), size = frame.Size(100, 100) }, nil, function(tree, data)
                ui.Leaf(tree, frame.Frame { pos = frame.Pos(10, 10), size = frame.Size(50, 50) })
            end)
        end,
        Stack = {
            { x = 10, y = 10, w = 100, h = 100 },
            { x = 20, y = 20, w = 50,  h = 50 },
        }
    },
    ["root fitting to one child"] = {
        Gen = function(tree)
            ui.Node(tree, frame.Frame { size = frame.Size(frame.Size.Fit(), frame.Size.Fit()) }, nil,
                function(tree, data)
                    ui.Leaf(tree, frame.Frame { size = frame.Size(50, 50) })
                    ui.Leaf(tree, frame.Frame { size = frame.Size(50, 50) })
                end)
        end,
        Stack = {
            { x = 0,  y = 0, w = 100, h = 50 },
            { x = 0,  y = 0, w = 50,  h = 50 },
            { x = 50, y = 0, w = 50,  h = 50 },
        }
    },
    ["root fitting to one child in vertical"] = {
        Gen = function(tree)
            ui.Node(tree,
                frame.Frame {
                    size = frame.Size(frame.Size.Fit(), frame.Size.Fit()),
                    layout = frame.Layout.Vertical(),
                },
                nil,
                function(tree, data)
                    ui.Leaf(tree, frame.Frame { size = frame.Size(50, 50) })
                end)
        end,
        Stack = {
            { x = 0, y = 0, w = 50, h = 50 },
            { x = 0, y = 0, w = 50, h = 50 },
        }
    },
    ["nested children, fixed positions"] = {
        Gen = function(tree)
            ui.Node(
                tree,
                frame.Frame { pos = frame.Pos(10, 15), size = frame.Size(200, 100) },
                nil,
                function(tree, data)
                    ui.Node(
                        tree,
                        frame.Frame { pos = frame.Pos(10, 15), size = frame.Size(150, 50) },
                        nil,
                        function(tree, data)
                            ui.Leaf(tree, frame.Frame { pos = frame.Pos(5, 5), size = frame.Size(20, 20) })
                        end
                    )
                end
            )
        end,
        Stack = {
            { x = 10, y = 15, w = 200, h = 100 },
            { x = 20, y = 30, w = 150, h = 50 },
            { x = 25, y = 35, w = 20,  h = 20 },
        }
    },
    ["nested children, fixed positions and padding"] = {
        Gen = function(tree)
            ui.Node(
                tree,
                frame.Frame {
                    pos = frame.Pos(10, 15),
                    size = frame.Size(200, 100),
                    padding = frame.Padding.HV(10, 20)
                },
                nil,
                function(tree, data)
                    ui.Node(
                        tree,
                        frame.Frame { pos = frame.Pos(10, 15), size = frame.Size(150, 50) },
                        nil,
                        function(tree, data)
                            ui.Leaf(tree, frame.Frame { pos = frame.Pos(5, 5), size = frame.Size(20, 20) })
                        end
                    )
                end
            )
        end,
        Stack = {
            { x = 10, y = 15, w = 200, h = 100 },
            { x = 30, y = 50, w = 150, h = 50 },
            { x = 35, y = 55, w = 20,  h = 20 },
        }
    },
    ["default horizontal layout"] = {
        Gen = function(tree)
            ui.Node(
                tree,
                frame.Frame { size = frame.Size(200, 100) },
                nil,
                function(tree, data)
                    ui.Leaf(tree, frame.Frame { size = frame.Size(50, 100) })
                    ui.Leaf(tree, frame.Frame { size = frame.Size(100, 50) })
                end
            )
        end,
        Stack = {
            { x = 0,  y = 0, w = 200, h = 100 },
            { x = 0,  y = 0, w = 50,  h = 100 },
            { x = 50, y = 0, w = 100, h = 50 },
        }
    },
    ["default horizontal layout with margin"] = {
        Gen = function(tree)
            ui.Node(
                tree,
                frame.Frame { size = frame.Size(200, 100), margin = 10 },
                nil,
                function(tree, data)
                    ui.Leaf(tree, frame.Frame { size = frame.Size(50, 100) })
                    ui.Leaf(tree, frame.Frame { size = frame.Size(100, 50) })
                end
            )
        end,
        Stack = {
            { x = 0,  y = 0, w = 200, h = 100 },
            { x = 0,  y = 0, w = 50,  h = 100 },
            { x = 60, y = 0, w = 100, h = 50 },
        }
    },
    ["vertical layout"] = {
        Gen = function(tree)
            ui.Node(
                tree,
                frame.Frame { size = frame.Size(200, 300), layout = frame.Layout.Vertical() },
                nil,
                function(tree, data)
                    ui.Leaf(tree, frame.Frame { size = frame.Size(50, 100) })
                    ui.Leaf(tree, frame.Frame { size = frame.Size(100, 50) })
                end
            )
        end,
        Stack = {
            { x = 0, y = 0,   w = 200, h = 300 },
            { x = 0, y = 0,   w = 50,  h = 100 },
            { x = 0, y = 100, w = 100, h = 50 },
        }
    },
    ["vertical layout with spacing"] = {
        Gen = function(tree)
            ui.Node(
                tree,
                frame.Frame { size = frame.Size(200, 300), layout = frame.Layout.Vertical(), margin = 10 },
                nil,
                function(tree, data)
                    ui.Leaf(tree, frame.Frame { size = frame.Size(50, 100) })
                    ui.Leaf(tree, frame.Frame { size = frame.Size(100, 50) })
                end
            )
        end,
        Stack = {
            { x = 0, y = 0,   w = 200, h = 300 },
            { x = 0, y = 0,   w = 50,  h = 100 },
            { x = 0, y = 110, w = 100, h = 50 },
        }
    },
    ["default horizontal layout with margin and root fitting children size"] = {
        Gen = function(tree)
            ui.Node(
                tree,
                frame.Frame { padding = frame.Padding.All(10), margin = 10 },
                nil,
                function(tree, data)
                    ui.Leaf(tree, frame.Frame { size = frame.Size(50, 100) })
                    ui.Leaf(tree, frame.Frame { size = frame.Size(100, 50) })
                end
            )
        end,
        Stack = {
            { x = 0,  y = 0,  w = 180, h = 120 },
            { x = 10, y = 10, w = 50,  h = 100 },
            { x = 70, y = 10, w = 100, h = 50 },
        }
    },
    ["vertical layout with margin and root fitting children size"] = {
        Gen = function(tree)
            ui.Node(
                tree,
                frame.Frame { padding = frame.Padding.All(10), layout = frame.Layout.Vertical(), margin = 10 },
                nil,
                function(tree, data)
                    ui.Leaf(tree, frame.Frame { size = frame.Size(50, 100) })
                    ui.Leaf(tree, frame.Frame { size = frame.Size(100, 50) })
                end
            )
        end,
        Stack = {
            { x = 0,  y = 0,   w = 120, h = 180 },
            { x = 10, y = 10,  w = 50,  h = 100 },
            { x = 10, y = 120, w = 100, h = 50 },
        }
    },

    ["grow children between two fixed size in horizontal"] = {
        Gen = function(tree)
            ui.Node(
                tree,
                frame.Frame { size = frame.Size(450, frame.Size.Fit()), padding = frame.Padding.All(10), margin = 10 },
                nil,
                function(tree, data)
                    ui.Leaf(tree, frame.Frame { size = frame.Size(50, 100) })
                    ui.Leaf(tree, frame.Frame { size = frame.Size(frame.Size.Grow(), frame.Size.Grow()) })
                    ui.Leaf(tree, frame.Frame { size = frame.Size(100, 50) })
                end
            )
        end,
        Stack = {
            { x = 0,   y = 0,  w = 450, h = 120 },
            { x = 10,  y = 10, w = 50,  h = 100 },
            { x = 70,  y = 10, w = 260, h = 100 },
            { x = 340, y = 10, w = 100, h = 50 },
        }
    },

    ["grow children between two fixed size in vertical"] = {
        Gen = function(tree)
            ui.Node(
                tree,
                frame.Frame {
                    size = frame.Size(frame.Size.Fit(), 450),
                    padding = frame.Padding.All(10),
                    layout = frame.Layout.Vertical(),
                    margin = 10,
                },
                nil,
                function(tree, data)
                    ui.Leaf(tree, frame.Frame { size = frame.Size(100, 50) })
                    ui.Leaf(tree, frame.Frame { size = frame.Size(frame.Size.Grow(), frame.Size.Grow()) })
                    ui.Leaf(tree, frame.Frame { size = frame.Size(50, 100) })
                end
            )
        end,
        Stack = {
            { x = 0,  y = 0,   w = 120, h = 450 },
            { x = 10, y = 10,  w = 100, h = 50 },
            { x = 10, y = 70,  w = 100, h = 260 },
            { x = 10, y = 340, w = 50,  h = 100 },
        }
    },

    ["two grow children between two fixed size in horizontal with starting size"] = {
        Gen = function(tree)
            ui.Node(
                tree,
                frame.Frame { size = frame.Size(450, frame.Size.Fit()), padding = frame.Padding.All(10), margin = 10 },
                nil,
                function(tree, data)
                    ui.Leaf(tree, frame.Frame { size = frame.Size(50, 100) })
                    ui.Leaf(tree,
                        frame.Frame {
                            size = frame.Size(frame.Size.Grow(), frame.Size.Grow()),
                            painter = { x = 10, y = 15 }
                        })
                    ui.Leaf(tree, frame.Frame { size = frame.Size(frame.Size.Grow(), frame.Size.Grow()) })
                    ui.Leaf(tree, frame.Frame { size = frame.Size(100, 50) })
                end
            )
        end,
        Stack = {
            { x = 0,   y = 0,  w = 450, h = 120 },
            { x = 10,  y = 10, w = 50,  h = 100 },
            { x = 70,  y = 10, w = 125, h = 100, painter = { x = 10, y = 15 } },
            { x = 205, y = 10, w = 125, h = 100 },
            { x = 340, y = 10, w = 100, h = 50 },
        }
    },


    ["two grow children between two fixed size in vertical with starting size"] = {
        Gen = function(tree)
            ui.Node(
                tree,
                frame.Frame {
                    size = frame.Size(frame.Size.Fit(), 450),
                    padding = frame.Padding.All(10),
                    layout = frame.Layout.Vertical(),
                    margin = 10,
                },
                nil,
                function(tree, data)
                    ui.Leaf(tree, frame.Frame { size = frame.Size(100, 50) })
                    ui.Leaf(tree, frame.Frame { size = frame.Size(frame.Size.Grow(), frame.Size.Grow()) })
                    ui.Leaf(tree, frame.Frame {
                        size = frame.Size(frame.Size.Grow(), frame.Size.Grow()),
                        painter = { x = 10, y = 15 }
                    })
                    ui.Leaf(tree, frame.Frame { size = frame.Size(50, 100) })
                end
            )
        end,
        Stack = {
            { x = 0,  y = 0,   w = 120, h = 450 },
            { x = 10, y = 10,  w = 100, h = 50 },
            { x = 10, y = 70,  w = 100, h = 125 },
            { x = 10, y = 205, w = 100, h = 125, painter = { x = 10, y = 15 } },
            { x = 10, y = 340, w = 50,  h = 100 },
        }
    },

    ["two grow children between two fixed size in horizontal with one shrinking"] = {
        Gen = function(tree)
            ui.Node(
                tree,
                frame.Frame {
                    size = frame.Size(450, frame.Size.Fit()),
                    padding = frame.Padding.All(10),
                    margin = 10
                },
                nil,
                function(tree, data)
                    ui.Leaf(tree, frame.Frame { size = frame.Size(50, 100) })
                    ui.Leaf(tree, frame.Frame {
                        size = frame.Size(frame.Size.Grow(), frame.Size.Grow()),
                        painter = { x = 500, y = 15 }
                    })
                    ui.Leaf(tree, frame.Frame { size = frame.Size(frame.Size.Grow(), frame.Size.Grow()) })
                    ui.Leaf(tree, frame.Frame { size = frame.Size(100, 50) })
                end
            )
        end,
        Stack = {
            { x = 0,   y = 0,  w = 450, h = 410 },
            { x = 10,  y = 10, w = 50,  h = 100 },
            { x = 70,  y = 10, w = 125, h = 390, painter = { x = 500, y = 15 } },
            { x = 205, y = 10, w = 125, h = 390 },
            { x = 340, y = 10, w = 100, h = 50 },
        }
    },

    ["two grow children between two fixed size in vertical with one shrinking"] = {
        Gen = function(tree)
            ui.Node(
                tree,
                frame.Frame {
                    size = frame.Size(frame.Size.Fit(), 450),
                    padding = frame.Padding.All(10),
                    layout = frame.Layout.Vertical(),
                    margin = 10,
                },
                nil,
                function(tree, data)
                    ui.Leaf(tree, frame.Frame { size = frame.Size(100, 50) })
                    ui.Leaf(tree, frame.Frame { size = frame.Size(frame.Size.Grow(), frame.Size.Grow()) })
                    ui.Leaf(tree, frame.Frame {
                        size = frame.Size(frame.Size.Grow(), frame.Size.Grow()),
                        painter = { x = 10, y = 500 }
                    })
                    ui.Leaf(tree, frame.Frame { size = frame.Size(50, 100) })
                end
            )
        end,
        Stack = {
            { x = 0,  y = 0,   w = 120, h = 450 },
            { x = 10, y = 10,  w = 100, h = 50 },
            { x = 10, y = 70,  w = 100, h = 125 },
            { x = 10, y = 205, w = 100, h = 125, painter = { x = 10, y = 500 } },
            { x = 10, y = 340, w = 50,  h = 100 },
        }
    },

    ["centered alignment"] = {
        Gen = function(tree)
            ui.Node(
                tree,
                frame.Frame {
                    size = frame.Size(400, 400),
                    padding = frame.Padding.All(10),
                    margin = 10,
                    align = frame.Align(frame.Align.Middle(), frame.Align.Middle()),
                },
                nil,
                function(tree, data)
                    ui.Leaf(tree, frame.Frame { size = frame.Size(100, 50) })
                    ui.Leaf(tree, frame.Frame { size = frame.Size(50, 100) })
                end
            )
        end,
        Stack = {
            { x = 0,   y = 0,   w = 400, h = 400 },
            { x = 120, y = 175, w = 100, h = 50 },
            { x = 230, y = 150, w = 50,  h = 100 },
        }
    },

    ["bottom left alignment"] = {
        Gen = function(tree)
            ui.Node(
                tree,
                frame.Frame {
                    size = frame.Size(400, 400),
                    padding = frame.Padding.All(10),
                    margin = 10,
                    align = frame.Align(frame.Align.Begin(), frame.Align.End()),
                },
                nil,
                function(tree, data)
                    ui.Leaf(tree, frame.Frame { size = frame.Size(100, 50) })
                    ui.Leaf(tree, frame.Frame { size = frame.Size(50, 100) })
                end
            )
        end,
        Stack = {
            { x = 0,   y = 0,   w = 400, h = 400 },
            { x = 10,  y = 340, w = 100, h = 50 },
            { x = 120, y = 290, w = 50,  h = 100 },
        }
    },


    ["shrink to min size"] = {
        Gen = function(tree)
            ui.Node(
                tree,
                frame.Frame {
                    size = frame.Size(200, 200),
                    padding = frame.Padding.All(10),
                    margin = 10
                },
                nil,
                function(tree, data)
                    ui.Leaf(
                        tree,
                        frame.Frame {
                            size = frame.Size(frame.Size.Grow(100), frame.Size.Grow(100)),
                            painter = { x = 200, y = 200 },
                        }
                    )
                    ui.Leaf(
                        tree,
                        frame.Frame {
                            size = frame.Size(frame.Size.Grow(), frame.Size.Grow()),
                            painter = { x = 200, y = 200 },
                        }
                    )
                end
            )
        end,
        Stack = {
            { x = 0,   y = 0,  w = 200, h = 200 },
            { x = 10,  y = 10, w = 100, h = 180, painter = { x = 200, y = 200 } },
            { x = 120, y = 10, w = 70,  h = 180, painter = { x = 200, y = 200 } },
        }
    },

    ["fit to min size"] = {
        Gen = function(tree)
            ui.Node(
                tree,
                frame.Frame {
                    size = frame.Size(
                        frame.Size.Fit(100),
                        frame.Size.Fit(200)
                    ),
                    padding = frame.Padding.All(10),
                    margin = 10
                },
                nil,
                function(tree, data)
                    ui.Leaf(tree, frame.Frame { size = frame.Size(50, 50) })
                end
            )
        end,
        Stack = {
            { x = 0,  y = 0,  w = 100, h = 200 },
            { x = 10, y = 10, w = 50,  h = 50 },
        }
    },


    ["dont shrink min size"] = {
        Gen = function(tree)
            ui.Node(
                tree,
                frame.Frame {
                    size = frame.Size(100, 100),
                    padding = frame.Padding.All(10),
                    margin = 10
                },
                nil,
                function(tree, data)
                    ui.Leaf(
                        tree,
                        frame.Frame { size = frame.Size(50, 100) }
                    )
                    ui.Leaf(
                        tree,
                        frame.Frame { size = frame.Size(50, 100) }
                    )
                end
            )
        end,
        Stack = {
            { x = 0,  y = 0,  w = 100, h = 100 },
            { x = 10, y = 10, w = 50,  h = 100 },
            { x = 70, y = 10, w = 50,  h = 100 },
        }
    },

    ["dont grow over max size"] = {
        Gen = function(tree)
            ui.Node(
                tree,
                frame.Frame {
                    size = frame.Size(450, frame.Size.Fit()),
                    padding = frame.Padding.All(10),
                    margin = 10
                },
                nil,
                function(tree, data)
                    ui.Leaf(tree, frame.Frame { size = frame.Size(frame.Size.Grow(0, 50), 50) })
                    ui.Leaf(tree, frame.Frame { size = frame.Size(frame.Size.Grow(0, 50), 50) })
                end
            )
        end,
        Stack = {
            { x = 0,  y = 0,  w = 450, h = 70 },
            { x = 10, y = 10, w = 50,  h = 50 },
            { x = 70, y = 10, w = 50,  h = 50 },
        }
    },


    ["dont fit over max width size"] = {
        Gen = function(tree)
            ui.Node(
                tree,
                frame.Frame {
                    size = frame.Size(frame.Size.Fit(0, 100), frame.Size.Fit()),
                    padding = frame.Padding.All(10),
                    margin = 10
                },
                nil,
                function(tree, data)
                    ui.Leaf(tree, frame.Frame {
                        size = frame.Size(frame.Size.Grow(), frame.Size.Grow()),
                        painter = { x = 100, y = 100 },
                    })
                    ui.Leaf(tree, frame.Frame {
                        size = frame.Size(frame.Size.Grow(), frame.Size.Grow()),
                        painter = { x = 100, y = 100 }
                    })
                end
            )
        end,
        Stack = {
            { x = 0,  y = 0,  w = 100, h = 185 },
            { x = 10, y = 10, w = 35,  h = 165, painter = { x = 100, y = 100 } },
            { x = 55, y = 10, w = 35,  h = 165, painter = { x = 100, y = 100 } },
        }
    },

    ["one line basic table example"] = {
        Gen = function(tree)
            ui.Node(
                tree,
                frame.Frame {
                    layout = frame.Layout.Vertical(),
                    padding = frame.Padding.All(10),
                    margin = 10
                },
                nil,
                function(tree, ud)
                    local data = { { x = 100, y = 25 } }
                    for _, d in ipairs(data) do
                        ui.Node(
                            tree,
                            frame.Frame {
                                size = frame.Size(frame.Size.Grow(), frame.Size.Fit()),
                                padding = frame.Padding.All(10),
                                margin = 10
                            },
                            d,
                            function(tree, ud)
                                ui.Leaf(tree, frame.Frame {
                                    size = frame.Size(frame.Size.Grow(), frame.Size.Grow()),
                                    painter = ud
                                })
                                ui.Leaf(tree, frame.Frame { size = frame.Size(25, 25) })
                            end
                        )
                    end
                end
            )
        end,
        Stack = {
            { x = 0,   y = 0,  w = 175, h = 65 },
            { x = 10,  y = 10, w = 155, h = 45 },
            { x = 20,  y = 20, w = 100, h = 25, painter = { x = 100, y = 25 } },
            { x = 130, y = 20, w = 25,  h = 25 },
        }
    },


    ["two line basic table example"] = {
        Gen = function(tree)
            ui.Node(
                tree,
                frame.Frame {
                    layout = frame.Layout.Vertical(),
                    padding = frame.Padding.All(10),
                    margin = 10
                },
                nil,
                function(tree, ud)
                    local data = { { x = 100, y = 25 }, { x = 25, y = 25 } }
                    for _, d in ipairs(data) do
                        ui.Node(
                            tree,
                            frame.Frame {
                                size = frame.Size(frame.Size.Grow(), frame.Size.Fit()),
                                padding = frame.Padding.All(10),
                                margin = 10
                            },
                            d,
                            function(tree, ud)
                                local item = ud
                                ui.Leaf(tree, frame.Frame {
                                    size = frame.Size(frame.Size.Grow(), frame.Size.Grow()),
                                    painter = item
                                })
                                ui.Leaf(tree, frame.Frame { size = frame.Size(25, 25) })
                            end
                        )
                    end
                end
            )
        end,
        Stack = {
            { x = 0,   y = 0,  w = 175, h = 120 },
            { x = 10,  y = 10, w = 155, h = 45 },
            { x = 20,  y = 20, w = 100, h = 25, painter = { x = 100, y = 25 } },
            { x = 130, y = 20, w = 25,  h = 25 },
            { x = 10,  y = 65, w = 155, h = 45 },
            { x = 20,  y = 75, w = 100, h = 25, painter = { x = 25, y = 25 } },
            { x = 130, y = 75, w = 25,  h = 25 },
        }
    },

    ["one line basic table example in vertical"] = {
        Gen = function(tree)
            ui.Node(
                tree,
                frame.Frame {
                    padding = frame.Padding.All(10),
                    margin = 10
                },
                nil,
                function(tree, ud)
                    local data = { { x = 25, y = 100 } }
                    for _, d in ipairs(data) do
                        ui.Node(
                            tree,
                            frame.Frame {
                                layout = frame.Layout.Vertical(),
                                size = frame.Size(frame.Size.Fit(), frame.Size.Grow()),
                                padding = frame.Padding.All(10),
                                margin = 10
                            },
                            d,
                            function(tree, ud)
                                local item = ud
                                ui.Leaf(tree, frame.Frame {
                                    size = frame.Size(frame.Size.Grow(), frame.Size.Grow()),
                                    painter = item
                                })
                                ui.Leaf(tree, frame.Frame { size = frame.Size(25, 25) })
                            end
                        )
                    end
                end
            )
        end,
        Stack = {
            { x = 0,  y = 0,   w = 65, h = 175 },
            { x = 10, y = 10,  w = 45, h = 155 },
            { x = 20, y = 20,  w = 25, h = 100, painter = { x = 25, y = 100 } },
            { x = 20, y = 130, w = 25, h = 25 },
        }
    },

    ["two line basic table example reverse order"] = {
        Gen = function(tree)
            ui.Node(
                tree,
                frame.Frame {
                    layout = frame.Layout.Vertical(),
                    padding = frame.Padding.All(10),
                    margin = 10
                },
                nil,
                function(tree, ud)
                    local data = { { x = 25, y = 25 }, { x = 100, y = 25 } }
                    for _, d in ipairs(data) do
                        ui.Node(
                            tree,
                            frame.Frame {
                                size = frame.Size(frame.Size.Grow(), frame.Size.Fit()),
                                padding = frame.Padding.All(10),
                                margin = 10
                            },
                            d,
                            function(tree, ud)
                                local item = ud
                                ui.Leaf(tree, frame.Frame {
                                    size = frame.Size(frame.Size.Grow(), frame.Size.Grow()),
                                    painter = item
                                })
                                ui.Leaf(tree, frame.Frame { size = frame.Size(25, 25) })
                            end
                        )
                    end
                end
            )
        end,
        Stack = {
            { x = 0,   y = 0,  w = 175, h = 120 },
            { x = 10,  y = 10, w = 155, h = 45 },
            { x = 20,  y = 20, w = 100, h = 25, painter = { x = 25, y = 25 } },
            { x = 130, y = 20, w = 25,  h = 25 },
            { x = 10,  y = 65, w = 155, h = 45 },
            { x = 20,  y = 75, w = 100, h = 25, painter = { x = 100, y = 25 } },
            { x = 130, y = 75, w = 25,  h = 25 },
        }
    },


    ["stack layout"] = {
        Gen = function(tree)
            ui.Node(
                tree,
                frame.Frame {
                    size = frame.Size(frame.Size.Fit(), frame.Size.Fit()),
                    layout = frame.Layout.Stack(),
                    padding = frame.Padding.All(10),
                    margin = 10
                },
                nil,
                function(tree, data)
                    ui.Leaf(tree, frame.Frame { size = frame.Size(100, 50) })
                    ui.Leaf(tree, frame.Frame { size = frame.Size(50, 100) })
                end
            )
        end,
        Stack = {
            { x = 0,  y = 0,  w = 120, h = 120 },
            { x = 10, y = 10, w = 100, h = 50 },
            { x = 10, y = 10, w = 50,  h = 100 },
        }
    },


}

for name, tt in pairs(tests) do
    print("running test " .. name)
    local tree = TestTree()
    tt.Gen(tree)
    -- print("gen tree :" .. PrintValue(tree, ""))
    ui.DrawTree(tree)

    for i, expected in ipairs(tt.Stack) do
        if not testing.match(expected, tree.Commands[i]) then
            print(string.format(
                "[%s:%d] exp -%s- got -%s-",
                name,
                i,
                testing.PrintValue(expected),
                testing.PrintValue(tree.Commands[i])
            ))
        end
    end
end
print("done")
