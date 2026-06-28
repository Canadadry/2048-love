return {
  {
    name = "empty_string_no_draw",
    input = {
      txt = "",
      window = {
        width = 10,
        height = 4
      },
      rect = {
        x = 0,
        y = 0,
        width = 10,
        height = 4
      },
      font = {
        size = 1,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "begin"
        }
      }
    },
    expected = {
      buffer = {
        "          ",
        "          ",
        "          ",
        "          "
      }
    }
  },
  {
    name = "wrap_single_line",
    input = {
      txt = "Hi",
      window = {
        width = 10,
        height = 4
      },
      rect = {
        x = 0,
        y = 0,
        width = 10,
        height = 4
      },
      font = {
        size = 1,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "begin"
        }
      }
    },
    expected = {
      buffer = {
        "Hi        ",
        "          ",
        "          ",
        "          "
      }
    }
  },
  {
    name = "wrap_two_lines_smaall_window",
    input = {
      txt = "Hi world",
      window = {
        width = 10,
        height = 4
      },
      rect = {
        x = 0,
        y = 0,
        width = 5,
        height = 4
      },
      font = {
        size = 1,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "begin"
        }
      }
    },
    expected = {
      buffer = {
        "Hi        ",
        "world     ",
        "          ",
        "          "
      }
    }
  },
  {
    name = "align_begin_begin_single_line_offset_and_small_window",
    input = {
      txt = "Hi",
      window = {
        width = 10,
        height = 4
      },
      rect = {
        x = 2,
        y = 1,
        width = 6,
        height = 3
      },
      font = {
        size = 1,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "begin"
        }
      }
    },
    expected = {
      buffer = {
        "          ",
        "  Hi      ",
        "          ",
        "          "
      }
    }
  },
  {
    name = "align_begin_begin_multiline_offset_and_small_window",
    input = {
      txt = "Hi\nworld",
      window = {
        width = 10,
        height = 4
      },
      rect = {
        x = 2,
        y = 1,
        width = 6,
        height = 3
      },
      font = {
        size = 1,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "begin"
        }
      }
    },
    expected = {
      buffer = {
        "          ",
        "  Hi      ",
        "  world   ",
        "          "
      }
    }
  },
  {
    name = "align_middle_begin_single_line_offset_and_small_window",
    input = {
      txt = "Hi",
      window = {
        width = 10,
        height = 4
      },
      rect = {
        x = 2,
        y = 1,
        width = 6,
        height = 3
      },
      font = {
        size = 1,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "middle",
          y = "begin"
        }
      }
    },
    expected = {
      buffer = {
        "          ",
        "    Hi    ",
        "          ",
        "          "
      }
    }
  },
  {
    name = "align_middle_begin_multiline_offset_and_small_window",
    input = {
      txt = "Hi\nworld",
      window = {
        width = 12,
        height = 4
      },
      rect = {
        x = 2,
        y = 1,
        width = 8,
        height = 3
      },
      font = {
        size = 1,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "middle",
          y = "begin"
        }
      }
    },
    expected = {
      buffer = {
        "            ",
        "     Hi     ",
        "   world    ",
        "            "
      }
    }
  },
  {
    name = "align_end_begin_single_line_offset_and_small_window",
    input = {
      txt = "Hi",
      window = {
        width = 10,
        height = 4
      },
      rect = {
        x = 2,
        y = 1,
        width = 6,
        height = 3
      },
      font = {
        size = 1,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "end",
          y = "begin"
        }
      }
    },
    expected = {
      buffer = {
        "          ",
        "      Hi  ",
        "          ",
        "          "
      }
    }
  },
  {
    name = "align_end_begin_multiline_offset_and_small_window",
    input = {
      txt = "Hi\nworld",
      window = {
        width = 12,
        height = 4
      },
      rect = {
        x = 2,
        y = 1,
        width = 8,
        height = 3
      },
      font = {
        size = 1,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "end",
          y = "begin"
        }
      }
    },
    expected = {
      buffer = {
        "            ",
        "        Hi  ",
        "     world  ",
        "            "
      }
    }
  },
  {
    name = "align_begin_middle_single_line_offset_and_small_window",
    input = {
      txt = "Hi",
      window = {
        width = 10,
        height = 4
      },
      rect = {
        x = 2,
        y = 1,
        width = 6,
        height = 3
      },
      font = {
        size = 1,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "middle"
        }
      }
    },
    expected = {
      buffer = {
        "          ",
        "          ",
        "  Hi      ",
        "          "
      }
    }
  },
  {
    name = "align_begin_middle_multiline_offset_and_small_window",
    input = {
      txt = "Hi\nworld",
      window = {
        width = 10,
        height = 5
      },
      rect = {
        x = 2,
        y = 1,
        width = 6,
        height = 4
      },
      font = {
        size = 1,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "middle"
        }
      }
    },
    expected = {
      buffer = {
        "          ",
        "          ",
        "  Hi      ",
        "  world   ",
        "          "
      }
    }
  },
  {
    name = "align_middle_middle_single_line_offset_and_small_window",
    input = {
      txt = "Hi",
      window = {
        width = 10,
        height = 5
      },
      rect = {
        x = 2,
        y = 1,
        width = 6,
        height = 4
      },
      font = {
        size = 1,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "middle",
          y = "middle"
        }
      }
    },
    expected = {
      buffer = {
        "          ",
        "          ",
        "    Hi    ",
        "          ",
        "          "
      }
    }
  },
  {
    name = "align_begin_end_single_line_offset_and_small_window",
    input = {
      txt = "Hi",
      window = {
        width = 10,
        height = 5
      },
      rect = {
        x = 2,
        y = 1,
        width = 6,
        height = 4
      },
      font = {
        size = 1,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "end"
        }
      }
    },
    expected = {
      buffer = {
        "          ",
        "          ",
        "          ",
        "          ",
        "  Hi      "
      }
    }
  },
  {
    name = "align_begin_end_multiline_offset_and_small_window",
    input = {
      txt = "Hi\nworld",
      window = {
        width = 10,
        height = 5
      },
      rect = {
        x = 2,
        y = 1,
        width = 6,
        height = 4
      },
      font = {
        size = 1,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "end"
        }
      }
    },
    expected = {
      buffer = {
        "          ",
        "          ",
        "          ",
        "  Hi      ",
        "  world   "
      }
    }
  },
  {
    name = "align_end_end_single_line_offset_and_small_window",
    input = {
      txt = "Hi",
      window = {
        width = 10,
        height = 5
      },
      rect = {
        x = 2,
        y = 1,
        width = 6,
        height = 4
      },
      font = {
        size = 1,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "end",
          y = "end"
        }
      }
    },
    expected = {
      buffer = {
        "          ",
        "          ",
        "          ",
        "          ",
        "      Hi  "
      }
    }
  },
  {
    name = "multiline_align_end_end_single_line_offset_and_small_window",
    input = {
      txt = "Hi\nworld",
      window = {
        width = 10,
        height = 5
      },
      rect = {
        x = 2,
        y = 1,
        width = 6,
        height = 4
      },
      font = {
        size = 1,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "end",
          y = "end"
        }
      }
    },
    expected = {
      buffer = {
        "          ",
        "          ",
        "          ",
        "      Hi  ",
        "   world  "
      }
    }
  },
  {
    name = "rect_overflow",
    input = {
      txt = "Hello world",
      window = {
        width = 12,
        height = 4
      },
      rect = {
        x = 5,
        y = 0,
        width = 15,
        height = 2
      },
      font = {
        size = 1,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "begin"
        }
      }
    },
    expected = {
      buffer = {
        "     Hello w",
        "            ",
        "            ",
        "            "
      }
    }
  },
  {
    name = "unicode_multibyte_draw_positions",
    input = {
      txt = "éà",
      window = {
        width = 10,
        height = 4
      },
      rect = {
        x = 0,
        y = 0,
        width = 10,
        height = 4
      },
      font = {
        size = 1,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "begin"
        }
      }
    },
    expected = {
      buffer = {
        "éà        ",
        "          ",
        "          ",
        "          "
      }
    }
  },
  {
    name = "spacing_offsets_x",
    input = {
      txt = "Hi",
      window = {
        width = 10,
        height = 4
      },
      rect = {
        x = 0,
        y = 0,
        width = 10,
        height = 4
      },
      font = {
        size = 1,
        spacing = 1,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "begin"
        }
      }
    },
    expected = {
      buffer = {
        "H i       ",
        "          ",
        "          ",
        "          "
      }
    }
  },
  {
    name = "line_spacing_offsets_y",
    input = {
      txt = "Hi\nworld",
      window = {
        width = 10,
        height = 6
      },
      rect = {
        x = 0,
        y = 0,
        width = 10,
        height = 6
      },
      font = {
        size = 1,
        spacing = 0,
        line_spacing = 1,
        align = {
          x = "begin",
          y = "begin"
        }
      }
    },
    expected = {
      buffer = {
        "Hi        ",
        "          ",
        "world     ",
        "          ",
        "          ",
        "          "
      }
    }
  }
}
