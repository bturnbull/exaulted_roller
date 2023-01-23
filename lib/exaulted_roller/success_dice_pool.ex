defmodule ExaultedRoller.SuccessDicePool do
  @moduledoc """
  A pool of Exaulted 3E success dice.
  """

  @default_success [7, 8, 9, 10]
  @default_double [10]

  alias ExaultedRoller.SuccessDie

  defstruct dice: [], success: @default_success, double: @default_double, stunt: 0, wound: 0

  @type t :: %__MODULE__{
          dice: [SuccessDie.t()],
          success: [1..10],
          double: [1..10],
          stunt: 0..3,
          wound: -4..0
        }

  @doc """
  Create a new `ExaultedRoller.SuccessDicePool` with `count` dice.

  Will count successes on 7, 8, 9, and 10 and double successes on 10.  See
  keyword arguments below to override.

  Keyword arguments:

    * `:success` - List of integers that represent success.
    * `:double` - List of integers that represent double success.
    * `:stunt` - The stunt level for this pool.
    * `:wound` - The wound penalty for this pool.

  ## Examples

      iex> ExaultedRoller.SuccessDicePool.create(3)
      %ExaultedRoller.SuccessDicePool{
        dice: [
          %ExaultedRoller.SuccessDie{value: 10, history: [{10, "Initial"}], frozen: false},
          %ExaultedRoller.SuccessDie{value: 7, history: [{7, "Initial"}], frozen: false},
          %ExaultedRoller.SuccessDie{value: 3, history: [{3, "Initial"}], frozen: false}
        ],
        success: [7, 8, 9, 10],
        double: [10],
        stunt: 0,
        wound: 0
      }

      iex> ExaultedRoller.SuccessDicePool.create(3, double: [9, 10], stunt: 2, wound: -1)
      %ExaultedRoller.SuccessDicePool{
        dice: [
          %ExaultedRoller.SuccessDie{value: 1, history: [{1, "Initial"}], frozen: false},
          %ExaultedRoller.SuccessDie{value: 9, history: [{9, "Initial"}], frozen: false},
          %ExaultedRoller.SuccessDie{value: 10, history: [{10, "Initial"}], frozen: false},
          %ExaultedRoller.SuccessDie{value: 7, history: [{7, "Initial"}], frozen: false}
        ],
        success: [7, 8, 9, 10],
        double: [9, 10],
        stunt: 2,
        wound: -1
      }

  """
  @spec create(pos_integer()) :: __MODULE__.t()
  @spec create(pos_integer(), keyword()) :: __MODULE__.t()
  def create(count, kwargs \\ []) do
    struct(%__MODULE__{}, kwargs)
    |> roll(count)
  end

  @doc """
  Roll an `ExaultedRoller.SuccessDicePool` replacing the current dice result.

  If you having an existing struct, this will fully replace the dice pool.  Use
  it to start a dice pool over with existing configuration.  if no `count` is
  passed, roll same number of dice as the passed `pool`.

  Returns `%ExaultedRoller.SuccessDicePool{}`

  ## Examples

      # Roll 4 dice subtracting 2 for wound penalty
      iex> pool = ExaultedRoller.SuccessDicePool.create(4, wound: -2)
      %ExaultedRoller.SuccessDicePool{
        dice: [
          %ExaultedRoller.SuccessDie{value: 6, history: [{6, "Initial"}], frozen: false},
          %ExaultedRoller.SuccessDie{value: 1, history: [{1, "Initial"}], frozen: false}
        ],
        success: [7, 8, 9, 10],
        double: [10],
        stunt: 0,
        wound: -2
      }

      # Roll 4 dice subtracting 2 for wound penalty (same as above)
      iex> ExaultedRoller.SuccessDicePool.roll(pool)
      %ExaultedRoller.SuccessDicePool{
        dice: [
          %ExaultedRoller.SuccessDie{value: 7, history: [{7, "Initial"}], frozen: false},
          %ExaultedRoller.SuccessDie{value: 10, history: [{10, "Initial"}], frozen: false}
        ],
        success: [7, 8, 9, 10],
        double: [10],
        stunt: 0,
        wound: -2
      }

      # Roll 5 dice using the same config (wound of -2 subtracts 2 dice from pool)
      iex> ExaultedRoller.SuccessDicePool.roll(pool, 5)
      %ExaultedRoller.SuccessDicePool{
        dice: [
          %ExaultedRoller.SuccessDie{value: 8, history: [{8, "Initial"}], frozen: false},
          %ExaultedRoller.SuccessDie{value: 5, history: [{5, "Initial"}], frozen: false},
          %ExaultedRoller.SuccessDie{value: 2, history: [{2, "Initial"}], frozen: false}
        ],
        success: [7, 8, 9, 10],
        double: [10],
        stunt: 0,
        wound: -2
      }

  """
  @spec roll(__MODULE__.t(), pos_integer) :: __MODULE__.t()
  def roll(%__MODULE__{} = pool, count) when is_integer(count) do
    dice =
      for i <- 0..(count + wound_dice_penalty(pool) + stunt_dice_bonus(pool)),
          i > 0,
          do: SuccessDie.create()

    Map.put(pool, :dice, dice)
  end

  @spec roll(__MODULE__.t()) :: __MODULE__.t()
  def roll(%__MODULE__{} = pool) do
    dice = for i <- 0..length(pool.dice), i > 0, do: SuccessDie.create()

    Map.put(pool, :dice, dice)
  end

  @doc """
  Returns true if the struct represents a botched roll.

  ## Examples

      iex> pool = ExaultedRoller.SuccessDicePool.create(2)
      %ExaultedRoller.SuccessDicePool{
        dice: [
          %ExaultedRoller.SuccessDie{value: 6, history: [{6, "Initial"}], frozen: false},
          %ExaultedRoller.SuccessDie{value: 1, history: [{1, "Initial"}], frozen: false}
        ],
        success: [7, 8, 9, 10],
        double: [10],
        stunt: 0,
        wound: 0
      }

      iex> ExaultedRoller.SuccessDicePool.botch?(pool)
      true

  """
  @spec botch?(__MODULE__.t()) :: boolean
  def botch?(%__MODULE__{} = pool) do
    Enum.any?(pool.dice, &(&1.value == 1)) and
      not Enum.any?(pool.dice, &die_success?(pool, &1)) and
      pool.stunt < 2
  end

  @doc """
  The number of successes in the pool.

  ## Examples

      iex> pool = ExaultedRoller.SuccessDicePool.create(2, stunt: 2)
      %ExaultedRoller.SuccessDicePool{
        dice: [
          %ExaultedRoller.SuccessDie{value: 10, history: [{10, "Initial"}], frozen: false},
          %ExaultedRoller.SuccessDie{value: 1, history: [{1, "Initial"}], frozen: false},
          %ExaultedRoller.SuccessDie{value: 7, history: [{7, "Initial"}], frozen: false},
          %ExaultedRoller.SuccessDie{value: 2, history: [{2, "Initial"}], frozen: false}
        ],
        success: [7, 8, 9, 10],
        double: [10],
        stunt: 2,
        wound: 0
      }

      # stunt: 2 adds an automatic success, 10s are doubled
      iex> ExaultedRoller.SuccessDicePool.success_count(pool)
      4

  """
  @spec success_count(__MODULE__.t()) :: non_neg_integer
  def success_count(%__MODULE__{} = pool) do
    Enum.count(pool.dice, &die_success?(pool, &1)) +
      Enum.count(pool.dice, &die_double?(pool, &1)) +
      automatic_success_count(pool)
  end

  @doc """
  The number of automatic successes in the pool.

  ## Examples

      iex> pool = ExaultedRoller.SuccessDicePool.create(2, stunt: 2)
      %ExaultedRoller.SuccessDicePool{
        dice: [
          %ExaultedRoller.SuccessDie{value: 10, history: [{10, "Initial"}], frozen: false},
          %ExaultedRoller.SuccessDie{value: 1, history: [{1, "Initial"}], frozen: false},
          %ExaultedRoller.SuccessDie{value: 7, history: [{7, "Initial"}], frozen: false},
          %ExaultedRoller.SuccessDie{value: 2, history: [{2, "Initial"}], frozen: false}
        ],
        success: [7, 8, 9, 10],
        double: [10],
        stunt: 2,
        wound: 0
      }

      # stunt: 2 adds 1 automatic success
      iex> ExaultedRoller.SuccessDicePool.automatic_success_count(pool)
      1

  """
  @spec automatic_success_count(__MODULE__.t()) :: 0..2
  def automatic_success_count(%__MODULE__{} = pool) do
    max(pool.stunt - 1, 0)
  end

  @doc """
  Returns the number of success dice added to the pool by the stunt level.
  """
  @spec stunt_dice_bonus(__MODULE__.t()) :: 0 | 2
  def stunt_dice_bonus(%__MODULE__{} = pool) do
    case pool.stunt do
      stunt when stunt in 1..3 ->
        2

      _ ->
        0
    end
  end

  @doc """
  Returns the number of success dice removed from the pool by the wound level.
  """
  @spec wound_dice_penalty(__MODULE__.t()) :: -4..0
  def wound_dice_penalty(%__MODULE__{} = pool) do
    pool.wound
  end

  @doc """
  Returns true if the passed `ExaultedRoller.SuccessDie` represents a success.
  """
  @spec die_success?(__MODULE__.t(), SuccessDie.t()) :: boolean
  def die_success?(%__MODULE__{} = pool, %SuccessDie{} = die) do
    Enum.member?(pool.success, die.value)
  end

  @doc """
  Returns true if the passed `ExaultedRoller.SuccessDie` represents a double success.
  """
  @spec die_double?(__MODULE__.t(), SuccessDie.t()) :: boolean
  def die_double?(%__MODULE__{} = pool, %SuccessDie{} = die) do
    Enum.member?(pool.double, die.value)
  end

  @doc """
  Reroll a subset of the pool per Exaulted 3E criteria.

  Criteria options:

    * `:not_success` - All dice that are not successes
    * `:not_10s` - All dice that are not tens
    * `[5, 6]` - All dice that are fives or sixes

  Count options:

    * `:once` - Roll the criteria one time
    * `:until_none` - Roll until criteria doesn't apply

  ## Examples

      iex> pool = ExaultedRoller.SuccessDicePool.create(3)
      %ExaultedRoller.SuccessDicePool{
        dice: [
          %ExaultedRoller.SuccessDie{value: 10, history: [{10, "Initial"}], frozen: false},
          %ExaultedRoller.SuccessDie{value: 7, history: [{7, "Initial"}], frozen: false},
          %ExaultedRoller.SuccessDie{value: 3, history: [{3, "Initial"}], frozen: false}
        ],
        success: [7, 8, 9, 10],
        double: [10],
        stunt: 0,
        wound: 0
      }

      iex> ExaultedRoller.SuccessDicePool.reroll(pool, :not_success, :once)
      %ExaultedRoller.SuccessDicePool{
        dice: [
          %ExaultedRoller.SuccessDie{value: 10, history: [{10, "Initial"}], frozen: false},
          %ExaultedRoller.SuccessDie{value: 7, history: [{7, "Initial"}], frozen: false},
          %ExaultedRoller.SuccessDie{value: 5, history: [{5, "Reroll non successes"}, {3, "Initial"}], frozen: false}
        ],
        success: [7, 8, 9, 10],
        double: [10],
        stunt: 0,
        wound: 0
      }

      iex> ExaultedRoller.SuccessDicePool.reroll(pool, [3, 4, 5], :until_none)
      %ExaultedRoller.SuccessDicePool{
        dice: [
          %ExaultedRoller.SuccessDie{value: 10, history: [{10, "Initial"}], frozen: false},
          %ExaultedRoller.SuccessDie{value: 7, history: [{7, "Initial"}], frozen: false},
          %ExaultedRoller.SuccessDie{
            value: 6,
            history: [
              {6, "Reroll until no [3, 4, 5]"}
              {5, "Reroll until no [3, 4, 5]"}
              {3, "Initial"}
            ],
            frozen: false
          }
        ],
        success: [7, 8, 9, 10],
        double: [10],
        stunt: 0,
        wound: 0
      }

  """
  @spec reroll(__MODULE__.t(), :not_success | :not_10s | [pos_integer], :once | :until_none) ::
          __MODULE__.t()
  def reroll(%__MODULE__{} = pool, :not_success, :once) do
    reroll(
      pool,
      Enum.filter(1..10, &(not Enum.member?(pool.success, &1))),
      :once,
      "Reroll non successes"
    )
  end

  def reroll(%__MODULE__{} = pool, :not_10s, :once) do
    reroll(pool, [1, 2, 3, 4, 5, 6, 7, 8, 9], :once, "Reroll non 10s")
  end

  def reroll(%__MODULE__{} = pool, values, :once) when is_list(values) do
    reroll(pool, values, :once, "Reroll no #{inspect(values)}")
  end

  def reroll(%__MODULE__{} = pool, values, :until_none) when is_list(values) do
    if Enum.any?(pool.dice, &Enum.member?(values, &1.value)) do
      reroll(pool, values, :once, "Reroll until no #{inspect(values)}")
      |> reroll(values, :until_none)
    else
      pool
    end
  end

  #####################################################################

  @doc false
  @spec reroll(__MODULE__.t(), [pos_integer], :once, String.t()) :: __MODULE__.t()
  defp reroll(%__MODULE__{} = pool, values, :once, reason)
       when is_list(values) and is_binary(reason) do
    %{
      pool
      | dice:
          Enum.map(pool.dice, fn die ->
            if Enum.member?(values, die.value) do
              SuccessDie.roll(die, reason)
            else
              die
            end
          end)
    }
  end
end