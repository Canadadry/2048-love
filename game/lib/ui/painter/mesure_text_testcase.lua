return {
  {
    name = "empty_string",
    input = {
      txt = "",
      width = 100,
      font = {
        size = 16,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "begin"
        }
      }
    },
    expected = {
      x = 0,
      y = 0
    }
  },
  {
    name = "null_string",
    input = {
      txt = nil,
      width = 100,
      font = {
        size = 16,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "begin"
        }
      }
    },
    expected = {
      x = 0,
      y = 0
    }
  },
  {
    name = "single_word_fits",
    input = {
      txt = "Hi!",
      width = 100,
      font = {
        size = 16,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "begin"
        }
      }
    },
    expected = {
      x = 24,
      y = 16
    }
  },
  {
    name = "single_word_exact_width",
    input = {
      txt = "Test",
      width = 32,
      font = {
        size = 16,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "begin"
        }
      }
    },
    expected = {
      x = 32,
      y = 16
    }
  },
  {
    name = "single_word_overflow",
    input = {
      txt = "Hello",
      width = 32,
      font = {
        size = 16,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "begin"
        }
      }
    },
    expected = {
      x = 40,
      y = 16
    }
  },
  {
    name = "two_words_wrap",
    input = {
      txt = "Hi world",
      width = 48,
      font = {
        size = 16,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "begin"
        }
      }
    },
    expected = {
      x = 40,
      y = 32
    }
  },
  {
    name = "wrap_multiple_lines",
    input = {
      txt = "Hi world foo bar",
      width = 48,
      font = {
        size = 16,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "begin"
        }
      }
    },
    expected = {
      x = 40,
      y = 64
    }
  },
  {
    name = "explicit_newline",
    input = {
      txt = "Hi\nworld",
      width = 100,
      font = {
        size = 16,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "begin"
        }
      }
    },
    expected = {
      x = 40,
      y = 32
    }
  },
  {
    name = "explicit_newline_empty_line",
    input = {
      txt = "Hi\n\nworld",
      width = 100,
      font = {
        size = 16,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "begin"
        }
      }
    },
    expected = {
      x = 40,
      y = 48
    }
  },
  {
    name = "trailing_newline_ignored",
    input = {
      txt = "Hi\n",
      width = 100,
      font = {
        size = 16,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "begin"
        }
      }
    },
    expected = {
      x = 16,
      y = 16
    }
  },
  {
    name = "ascii_only",
    input = {
      txt = "Hello",
      width = 100,
      font = {
        size = 16,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "begin"
        }
      }
    },
    expected = {
      x = 40,
      y = 16
    }
  },
  {
    name = "unicode_cjk",
    input = {
      txt = "你好吗",
      width = 100,
      font = {
        size = 16,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "begin"
        }
      }
    },
    expected = {
      x = 24,
      y = 16
    }
  },
  {
    name = "unicode_emoji",
    input = {
      txt = "😀",
      width = 100,
      font = {
        size = 16,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "begin"
        }
      }
    },
    expected = {
      x = 8,
      y = 16
    }
  },
  {
    name = "unicode_accent",
    input = {
      txt = "éàü",
      width = 100,
      font = {
        size = 16,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "begin"
        }
      }
    },
    expected = {
      x = 24,
      y = 16
    }
  },
  {
    name = "spacing_affects_width",
    input = {
      txt = "Hi!",
      width = 100,
      font = {
        size = 16,
        spacing = 2,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "begin"
        }
      }
    },
    expected = {
      x = 30,
      y = 16
    }
  },
  {
    name = "line_spacing_affects_height",
    input = {
      txt = "Hi\nworld",
      width = 100,
      font = {
        size = 16,
        spacing = 0,
        line_spacing = 4,
        align = {
          x = "begin",
          y = "begin"
        }
      }
    },
    expected = {
      x = 40,
      y = 36
    }
  },
  {
    name = "zero_width",
    input = {
      txt = "Hi\nworld",
      width = 0,
      font = {
        size = 16,
        spacing = 0,
        line_spacing = 0,
        align = {
          x = "begin",
          y = "begin"
        }
      }
    },
    expected = {
      x = 40,
      y = 32
    }
  }
}
