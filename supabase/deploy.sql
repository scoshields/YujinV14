-- Drop existing functions and policies
DROP FUNCTION IF EXISTS get_partner_stats(UUID);
DROP POLICY IF EXISTS "Enable read access for partners" ON daily_workouts;
DROP POLICY IF EXISTS "Enable read access for exercises" ON workout_exercises;
DROP POLICY IF EXISTS "Enable read access for sets" ON exercise_sets;

-- Create simplified partner stats function
CREATE OR REPLACE FUNCTION get_partner_stats(partner_id UUID)
RETURNS TABLE (
  total_workouts BIGINT,
  completed_workouts BIGINT,
  total_weight NUMERIC,
  completion_rate INTEGER
) AS $$
BEGIN
  RETURN QUERY
  WITH workout_stats AS (
    SELECT 
      d.id,
      d.completed,
      COALESCE(SUM(CASE WHEN es.completed AND es.weight > 0 AND es.reps > 0 THEN es.weight ELSE 0 END), 0) as weight
    FROM daily_workouts d
    LEFT JOIN workout_exercises we ON we.daily_workout_id = d.id
    LEFT JOIN exercise_sets es ON es.exercise_id = we.id
    WHERE d.user_id = partner_id
    AND d.date >= CURRENT_DATE - INTERVAL '7 days'
    GROUP BY d.id, d.completed
  )
  SELECT 
    COUNT(*)::BIGINT,
    COUNT(CASE WHEN completed THEN 1 END)::BIGINT,
    SUM(weight)::NUMERIC,
    CASE 
      WHEN COUNT(*) > 0 THEN 
        (COUNT(CASE WHEN completed THEN 1 END) * 100 / COUNT(*))::INTEGER
      ELSE 0 
    END
  FROM workout_stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_partner_stats(UUID) TO authenticated;

-- Create simplified RLS policies
CREATE POLICY "Enable read access for all" ON daily_workouts
  FOR SELECT USING (true);

CREATE POLICY "Enable read access for all" ON workout_exercises
  FOR SELECT USING (true);

CREATE POLICY "Enable read access for all" ON exercise_sets
  FOR SELECT USING (true);

-- Create workout completion function
CREATE OR REPLACE FUNCTION check_workout_completion()
RETURNS TRIGGER AS $$
DECLARE
  workout_id UUID;
BEGIN
  -- Get the workout ID for this exercise set
  SELECT d.id INTO workout_id
  FROM workout_exercises we
  JOIN daily_workouts d ON we.daily_workout_id = d.id
  WHERE we.id = NEW.exercise_id;

  -- Update the workout's completion status
  WITH workout_stats AS (
    SELECT 
      COUNT(*) as total_sets,
      COUNT(*) FILTER (WHERE es.completed AND es.weight > 0 AND es.reps > 0) as completed_sets
    FROM workout_exercises we
    JOIN exercise_sets es ON es.exercise_id = we.id
    WHERE we.daily_workout_id = workout_id
  )
  UPDATE daily_workouts
  SET 
    completed = (
      CASE 
        WHEN ws.total_sets > 0 AND ws.total_sets = ws.completed_sets THEN true
        ELSE false
      END
    ),
    updated_at = CURRENT_TIMESTAMP
  FROM workout_stats ws
  WHERE id = workout_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for exercise set updates
DROP TRIGGER IF EXISTS check_workout_completion_trigger ON exercise_sets;
CREATE TRIGGER check_workout_completion_trigger
  AFTER INSERT OR UPDATE OF completed, weight, reps ON exercise_sets
  FOR EACH ROW
  EXECUTE FUNCTION check_workout_completion();